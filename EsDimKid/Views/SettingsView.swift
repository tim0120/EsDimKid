import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }

            DisplaysSettingsView()
                .tabItem {
                    Label("Displays", systemImage: "display.2")
                }

            ExceptionsSettingsView()
                .tabItem {
                    Label("Exceptions", systemImage: "xmark.app")
                }
        }
        .frame(width: 450, height: 350)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var dimmingManager: DimmingManager

    var body: some View {
        Form {
            Section {
                Toggle("Enable dimming", isOn: $dimmingManager.isEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Intensity")
                        Spacer()
                        Text("\(Int(dimmingManager.intensity * 100))%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $dimmingManager.intensity, in: 0...1)
                }
            }

            Section {
                Toggle("Launch at login", isOn: $dimmingManager.launchAtLogin)
            }

            Section {
                HStack {
                    Text("Keyboard Shortcut")
                    Spacer()
                    ShortcutRecorderView(shortcut: $dimmingManager.globalShortcut)
                }
            }

            Section {
                AccessibilityStatusView()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @EnvironmentObject var dimmingManager: DimmingManager

    var body: some View {
        Form {
            Section("Appearance") {
                ColorPicker("Dimming color", selection: colorBinding)

                Picker("Highlight mode", selection: $dimmingManager.highlightMode) {
                    ForEach(HighlightMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Animation") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Animation Duration")
                        Spacer()
                        Text(dimmingManager.animationDuration == 0 ? "Instant" : String(format: "%.1fs", dimmingManager.animationDuration))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $dimmingManager.animationDuration, in: 0...2, step: 0.1)
                }

                Text("Respects \"Reduce Motion\" accessibility setting")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Behavior") {
                Toggle("Tap fn key to temporarily disable", isOn: $dimmingManager.fnKeyDisables)
            }

            Section("Appearance-specific Settings") {
                Toggle("Use separate settings for Light/Dark mode", isOn: $dimmingManager.useSeparateAppearanceSettings)

                if dimmingManager.useSeparateAppearanceSettings {
                    GroupBox("Light Mode") {
                        AppearanceSettingsEditor(settings: $dimmingManager.lightModeSettings)
                    }

                    GroupBox("Dark Mode") {
                        AppearanceSettingsEditor(settings: $dimmingManager.darkModeSettings)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: dimmingManager.color) },
            set: { dimmingManager.color = NSColor($0) }
        )
    }
}

// MARK: - Displays Settings

struct DisplaysSettingsView: View {
    @EnvironmentObject var dimmingManager: DimmingManager

    var body: some View {
        Form {
            Section("Multi-Display Behavior") {
                Picker("Display mode", selection: $dimmingManager.displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Connected Displays") {
                if NSScreen.screens.isEmpty {
                    Text("No displays detected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(NSScreen.screens.indices, id: \.self) { index in
                        let screen = NSScreen.screens[index]
                        HStack {
                            Image(systemName: index == 0 ? "display" : "display.2")
                            Text(screen.localizedName)
                            Spacer()
                            Text("\(Int(screen.frame.width)) × \(Int(screen.frame.height))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Exceptions Settings

struct ExceptionsSettingsView: View {
    @EnvironmentObject var dimmingManager: DimmingManager
    @State private var showingAppPicker = false

    var body: some View {
        Form {
            Section {
                Text("Dimming is disabled when these apps are active:")
                    .foregroundColor(.secondary)

                List {
                    ForEach(Array(dimmingManager.excludedBundleIDs).sorted(), id: \.self) { bundleID in
                        HStack {
                            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                Text(app.localizedName ?? bundleID)
                            } else {
                                Image(systemName: "app")
                                    .frame(width: 20, height: 20)
                                Text(bundleID)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        let sorted = Array(dimmingManager.excludedBundleIDs).sorted()
                        for index in indexSet {
                            dimmingManager.removeExcludedApp(sorted[index])
                        }
                    }
                }
                .frame(minHeight: 150)

                HStack {
                    Button("Add App...") {
                        showingAppPicker = true
                    }

                    Button("Remove Selected") {
                        // Would need selection state to implement
                    }
                    .disabled(true)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(onSelect: { bundleID in
                dimmingManager.addExcludedApp(bundleID)
                showingAppPicker = false
            }, onCancel: {
                showingAppPicker = false
            })
        }
    }
}

// MARK: - Helper Views

struct AppearanceSettingsEditor: View {
    @Binding var settings: AppearanceSettings

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Intensity")
                Slider(value: $settings.intensity, in: 0...1)
                Text("\(Int(settings.intensity * 100))%")
                    .monospacedDigit()
                    .frame(width: 40)
            }

            ColorPicker("Color", selection: colorBinding)
        }
        .padding(8)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { settings.color.color },
            set: { settings.color = CodableColor(nsColor: NSColor($0)) }
        )
    }
}

struct ShortcutRecorderView: View {
    @Binding var shortcut: KeyboardShortcutConfig

    var body: some View {
        Button {
            // TODO: Implement proper shortcut recording
        } label: {
            Text(shortcutDisplayString)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var shortcutDisplayString: String {
        var result = ""
        if shortcut.modifiers.contains("control") { result += "⌃" }
        if shortcut.modifiers.contains("option") { result += "⌥" }
        if shortcut.modifiers.contains("shift") { result += "⇧" }
        if shortcut.modifiers.contains("command") { result += "⌘" }
        result += shortcut.key.uppercased()
        return result
    }
}

struct AccessibilityStatusView: View {
    @State private var isAccessibilityEnabled = AXIsProcessTrusted()

    var body: some View {
        HStack {
            Image(systemName: isAccessibilityEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isAccessibilityEnabled ? .green : .orange)

            VStack(alignment: .leading) {
                Text(isAccessibilityEnabled ? "Accessibility Access Granted" : "Accessibility Access Required")
                    .font(.headline)
                Text("Required to track the active window")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isAccessibilityEnabled {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
        .onAppear {
            isAccessibilityEnabled = AXIsProcessTrusted()
        }
    }
}

struct AppPickerView: View {
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .filter { app in
                searchText.isEmpty || (app.localizedName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack {
            Text("Select an Application")
                .font(.headline)
                .padding()

            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(runningApps, id: \.bundleIdentifier) { app in
                Button {
                    if let bundleID = app.bundleIdentifier {
                        onSelect(bundleID)
                    }
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Text(app.localizedName ?? "Unknown")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }
}

// Preview requires Xcode
// #Preview {
//     SettingsView()
//         .environmentObject(DimmingManager.shared)
// }
