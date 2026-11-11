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
                Picker("Open search", selection: $settings.hotkey) {
                    ForEach(HotkeyPreset.allCases) { Text($0.label).tag($0) }
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
