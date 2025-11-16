//
//  SettingsDialogView.swift
//  MyRec
//
//  Simple settings dialog for app preferences
//

import SwiftUI

struct SettingsDialogView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var saveLocation: String = ""
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer for title spacing
            Spacer()
                .frame(height: 40)

            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Save Location
                HStack(spacing: 12) {
                    Text("Save Location:")
                        .frame(width: 140, alignment: .trailing)
                    TextField("", text: $saveLocation)
                        .textFieldStyle(.roundedBorder)
                    Button(action: chooseSaveLocation) {
                        Image(systemName: "folder")
                    }
                }

                Divider()

                // Startup
                HStack(spacing: 12) {
                    Text("Startup:")
                        .frame(width: 140, alignment: .trailing)
                    Toggle("Start at login", isOn: $launchAtLogin)
                }

                Divider()

                // Resolution & FPS
                HStack(spacing: 12) {
                    Text("Default Quality:")
                        .frame(width: 140, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Resolution:")
                                .foregroundColor(.secondary)
                            Picker("", selection: $settingsManager.defaultResolution) {
                                ForEach(Resolution.allCases.filter { $0 != .custom }, id: \.self) { resolution in
                                    Text(resolution.rawValue).tag(resolution)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        HStack(spacing: 8) {
                            Text("Frame Rate:")
                                .foregroundColor(.secondary)
                            Picker("", selection: $settingsManager.defaultFrameRate) {
                                ForEach(FrameRate.allCases, id: \.self) { fps in
                                    Text(fps.displayName).tag(fps)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                    }
                }

                Divider()

                // Keyboard Shortcuts
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("Start/Pause Recording:")
                            .frame(width: 180, alignment: .trailing)
                        Text("⌘⌥1")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }

                    HStack(spacing: 12) {
                        Text("Stop Recording:")
                            .frame(width: 180, alignment: .trailing)
                        Text("⌘⌥2")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // Version info
                HStack {
                    Spacer()
                    Text("MyRec v1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(width: 500, height: 450)
        .onAppear(perform: loadSettings)
        .onChange(of: saveLocation) { _ in saveSettings() }
        .onChange(of: launchAtLogin) { _ in saveSettings() }
    }

    private func loadSettings() {
        saveLocation = settingsManager.savePath.path
        launchAtLogin = settingsManager.launchAtLogin
    }

    private func saveSettings() {
        settingsManager.savePath = URL(fileURLWithPath: saveLocation)
        settingsManager.launchAtLogin = launchAtLogin
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose save location for recordings"

        if panel.runModal() == .OK, let url = panel.url {
            saveLocation = url.path
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsDialogView(settingsManager: SettingsManager.shared)
}
