import AppKit
import Carbon.HIToolbox
import Combine
import GipherCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var canAutoPaste = Paster.canAutoPaste
    @State private var loginError: String?

    private let refresh = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("GIPHY") {
                TextField("API key", text: $settings.apiKey)
                Link("Get a free key at developers.giphy.com",
                     destination: URL(string: "https://developers.giphy.com/dashboard/")!)
                Picker("Content rating up to", selection: $settings.rating) {
                    ForEach(Rating.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Paste size", selection: $settings.sendQuality) {
                    ForEach(SendQuality.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            Section("Shortcut") {
                LabeledContent("Open search") {
                    HotkeyRecorder(settings: settings)
                }
                if settings.hotkeyConflict {
                    Text("\(settings.hotkey.label) is already used by another app. Pick a different shortcut.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section("Pasting") {
                LabeledContent("Automatic paste") {
                    if canAutoPaste {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Allow in Accessibility…") { Paster.requestAutoPastePermission() }
                    }
                }
                if !canAutoPaste {
                    Text("Without this, TheGipher copies the GIF and you press ⌘V yourself.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("General") {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppearanceChoice.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(refresh) { _ in canAutoPaste = Paster.canAutoPaste }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "Couldn't change the login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// A button that shows the current shortcut; click it, then press the new one.
struct HotkeyRecorder: View {
    @ObservedObject var settings: AppSettings
    @State private var recording = false
    @State private var monitor: Any?
    @State private var rejected = false

    var body: some View {
        HStack(spacing: 8) {
            if recording {
                Text(rejected ? "Include ⌘, ⌥ or ⌃" : "Press a shortcut… (esc to cancel)")
                    .font(.caption)
                    .foregroundStyle(rejected ? .red : .secondary)
            }
            Button(recording ? "Recording" : settings.hotkey.label) {
                recording ? stop() : start()
            }
            .font(.system(.body, design: .rounded).weight(.semibold))
            .help("Click, then press the shortcut you want")
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        rejected = false
        settings.hotkeyPaused = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stop()
                return nil
            }
            var modifiers: UInt32 = 0
            if event.modifierFlags.contains(.command) { modifiers |= Hotkey.command }
            if event.modifierFlags.contains(.shift) { modifiers |= Hotkey.shift }
            if event.modifierFlags.contains(.option) { modifiers |= Hotkey.option }
            if event.modifierFlags.contains(.control) { modifiers |= Hotkey.control }
            let keyCode = UInt32(event.keyCode)
            let candidate = Hotkey(
                keyCode: keyCode, modifiers: modifiers,
                keyLabel: Hotkey.keyName(
                    keyCode: keyCode, characters: event.charactersIgnoringModifiers))
            if candidate.isUsable {
                settings.hotkey = candidate
                stop()
            } else {
                rejected = true
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        if settings.hotkeyPaused { settings.hotkeyPaused = false }
    }
}
