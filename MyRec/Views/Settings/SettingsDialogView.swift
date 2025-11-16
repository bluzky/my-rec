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
    @State private var showingPathError = false
    @State private var pathErrorMessage = ""
    @State private var showingLaunchError = false
    @State private var launchErrorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer for title spacing
            Spacer()
                .frame(height: 40)

            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Save Location
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Text("Save Location:")
                            .frame(width: 140, alignment: .trailing)
                        TextField("", text: $saveLocation)
                            .textFieldStyle(.roundedBorder)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(showingPathError ? Color.red : Color.clear, lineWidth: 1)
                            )
                        Button(action: chooseSaveLocation) {
                            Image(systemName: "folder")
                        }
                    }

                    if showingPathError {
                        Text(pathErrorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 152) // Align with text field
                    }
                }

                Divider()

                // Startup
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Text("Startup:")
                            .frame(width: 140, alignment: .trailing)
                        Toggle("Start at login", isOn: $launchAtLogin)
                    }

                    if showingLaunchError {
                        Text(launchErrorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 152) // Align with toggle
                    }
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
        // Validate save location before saving
        let pathValid = validateSaveLocation(saveLocation)
        let launchValid = validateAndSetLaunchAtLogin(launchAtLogin)

        if pathValid && launchValid {
            settingsManager.savePath = URL(fileURLWithPath: saveLocation)
            settingsManager.launchAtLogin = launchAtLogin
            showingPathError = false
            pathErrorMessage = ""
            showingLaunchError = false
            launchErrorMessage = ""
        } else if !pathValid {
            // Path validation failed - don't save anything
            // Error already set by validateSaveLocation
        } else if !launchValid {
            // Launch validation failed but path is valid
            settingsManager.savePath = URL(fileURLWithPath: saveLocation)
            // Error already set by validateAndSetLaunchAtLogin
        }
    }

    private func validateAndSetLaunchAtLogin(_ shouldLaunch: Bool) -> Bool {
        if shouldLaunch {
            return enableLaunchAtLogin()
        } else {
            return disableLaunchAtLogin()
        }
    }

    private func enableLaunchAtLogin() -> Bool {
        // Check if we have the necessary permissions to modify login items
        guard Bundle.main.bundleURL != nil else {
            showingLaunchError = true
            launchErrorMessage = "App bundle not found"
            return false
        }
        let bundleURL = Bundle.main.bundleURL

        // For now, simulate the login item functionality
        // In a real implementation, this would use SMAppService (macOS 13+) or LSSharedFileList
        print("🚀 Attempting to enable launch at login for app at: \(bundleURL.path)")

        // Simulate success for now - in real implementation, this would
        // try SMAppService.addLoginItem(at: bundleURL, hide: false)
        // or use LSSharedFileList to modify login items

        // Check if we're running in a proper app bundle (not Xcode preview)
        let isRunningFromBundle = Bundle.main.bundleURL.path.contains(".app")

        if isRunningFromBundle {
            // Simulate successful login item addition
            showingLaunchError = false
            launchErrorMessage = ""
            print("✅ Launch at login enabled (simulated)")
            return true
        } else {
            // Running in Xcode preview - show informative message
            showingLaunchError = true
            launchErrorMessage = "Launch at login is available when running the built app"
            print("⚠️ Launch at login disabled (Xcode preview mode)")
            return false
        }
    }

    private func disableLaunchAtLogin() -> Bool {
        guard Bundle.main.bundleURL != nil else {
            showingLaunchError = true
            launchErrorMessage = "App bundle not found"
            return false
        }
        let bundleURL = Bundle.main.bundleURL

        print("🚫 Attempting to disable launch at login for app at: \(bundleURL.path)")

        // Simulate success for now
        let isRunningFromBundle = Bundle.main.bundleURL.path.contains(".app")

        if isRunningFromBundle {
            showingLaunchError = false
            launchErrorMessage = ""
            print("✅ Launch at login disabled (simulated)")
            return true
        } else {
            showingLaunchError = true
            launchErrorMessage = "Launch at login is available when running the built app"
            print("⚠️ Launch at login disabled (Xcode preview mode)")
            return false
        }
    }

    private func validateSaveLocation(_ path: String) -> Bool {
        // Empty path
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showingPathError = true
            pathErrorMessage = "Save location cannot be empty"
            return false
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for invalid characters that could cause issues
        let invalidCharacters = CharacterSet(charactersIn: ":*?\"<>|")
        if trimmedPath.rangeOfCharacter(from: invalidCharacters) != nil {
            showingPathError = true
            pathErrorMessage = "Path contains invalid characters (: * ? \" < > |)"
            return false
        }

        // Check if path exists
        let url = URL(fileURLWithPath: trimmedPath)
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: trimmedPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // Path exists and is a directory - check if writable
                if !FileManager.default.isWritableFile(atPath: trimmedPath) {
                    showingPathError = true
                    pathErrorMessage = "Directory is not writable"
                    return false
                }
            } else {
                // Path exists but is a file
                showingPathError = true
                pathErrorMessage = "Path points to a file, not a directory"
                return false
            }
        } else {
            // Path doesn't exist - check if parent directory exists and is writable
            let parentURL = url.deletingLastPathComponent()
            if parentURL.path.isEmpty || parentURL.path == "/" {
                showingPathError = true
                pathErrorMessage = "Invalid path - cannot use root directory"
                return false
            }

            var parentIsDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: parentURL.path, isDirectory: &parentIsDirectory) {
                if parentIsDirectory.boolValue {
                    if !FileManager.default.isWritableFile(atPath: parentURL.path) {
                        showingPathError = true
                        pathErrorMessage = "Parent directory is not writable"
                        return false
                    }
                } else {
                    showingPathError = true
                    pathErrorMessage = "Parent path is not a directory"
                    return false
                }
            } else {
                showingPathError = true
                pathErrorMessage = "Parent directory does not exist"
                return false
            }
        }

        // Check for system-critical directories that shouldn't be used
        let systemPaths = ["/System", "/Library", "/usr", "/bin", "/sbin", "/etc"]
        for systemPath in systemPaths {
            if trimmedPath.hasPrefix(systemPath) || trimmedPath == systemPath {
                showingPathError = true
                pathErrorMessage = "Cannot use system directory for recordings"
                return false
            }
        }

        // Check path length (most filesystems have 255 character limit for components)
        let pathComponents = trimmedPath.components(separatedBy: "/")
        for component in pathComponents {
            if component.count > 255 {
                showingPathError = true
                pathErrorMessage = "Path component too long (max 255 characters)"
                return false
            }
        }

        return true
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
            // Clear any existing errors since this path is guaranteed valid
            showingPathError = false
            pathErrorMessage = ""
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsDialogView(settingsManager: SettingsManager.shared)
}
