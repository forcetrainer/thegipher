import AppKit
import ApplicationServices
import Carbon.HIToolbox
import GipherCore
import UniformTypeIdentifiers

enum PasteError: LocalizedError {
    case noRendition
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .noRendition: return "That GIF has no downloadable file."
        case .downloadFailed: return "Couldn't download the GIF."
        }
    }
}

/// Gets a GIF onto the clipboard as a file (the form Messages attaches and animates),
/// then presses ⌘V in the app you were typing in.
enum Paster {
    private static var outbox: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TheGipher/outbox", isDirectory: true)
    }

    static func download(_ gif: Gif, quality: SendQuality) async throws -> URL {
        guard let remote = gif.sendRendition(quality)?.url else { throw PasteError.noRendition }
        let (data, response) = try await URLSession.shared.data(from: remote)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw PasteError.downloadFailed
        }
        try FileManager.default.createDirectory(at: outbox, withIntermediateDirectories: true)
        let file = outbox.appendingPathComponent("\(fileStem(for: gif)).gif")
        try data.write(to: file, options: .atomic)
        return file
    }

    @MainActor private static var inFlight: [String: Task<URL, Error>] = [:]

    /// The downloaded file for a GIF, sharing one download between callers.
    @MainActor
    static func file(for gif: Gif, quality: SendQuality) -> Task<URL, Error> {
        let key = "\(gif.id)-\(quality.rawValue)"
        if let running = inFlight[key] { return running }
        let task = Task<URL, Error> {
            do {
                return try await download(gif, quality: quality)
            } catch {
                inFlight[key] = nil  // let a later attempt retry
                throw error
            }
        }
        inFlight[key] = task
        return task
    }

    /// What a dragged GIF hands to the app it's dropped on: the GIF file. The download
    /// starts when the drag does, so it's usually ready by the time of the drop.
    @MainActor
    static func dragProvider(for gif: Gif, quality: SendQuality) -> NSItemProvider {
        let fetch = file(for: gif, quality: quality)
        let provider = NSItemProvider()
        provider.suggestedName = fileStem(for: gif)
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.gif.identifier, fileOptions: [], visibility: .all
        ) { completion in
            Task {
                do {
                    let file = try await fetch.value
                    completion(file, false, nil)
                    await MainActor.run { RecentsStore.shared.add(gif) }
                } catch {
                    completion(nil, false, error)
                }
            }
            return nil
        }
        return provider
    }

    private static func fileStem(for gif: Gif) -> String {
        let words = gif.title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(6)
        let slug = words.joined(separator: "-")
        return slug.isEmpty ? gif.id : "\(slug)-\(gif.id)"
    }

    static func copy(_ file: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([file as NSURL])
    }

    static func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Pressing ⌘V in another app requires the Accessibility permission.
    static var canAutoPaste: Bool { AXIsProcessTrusted() }

    static func requestAutoPastePermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    static func pressPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Sent GIFs only need to live long enough to be pasted.
    static func pruneOutbox(olderThan age: TimeInterval = 86_400) {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(
            at: outbox, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified, Date().timeIntervalSince(modified) > age {
                try? fm.removeItem(at: file)
            }
        }
    }
}
