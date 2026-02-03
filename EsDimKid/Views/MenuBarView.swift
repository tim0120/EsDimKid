import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var dimmingManager: DimmingManager
    @Environment(\.openSettings) private var openSettings

    private var isDimEnabled: Bool {
        dimmingManager.dimmingStyle == .dim || dimmingManager.dimmingStyle == .dimAndBlur
    }

    private var isBlurEnabled: Bool {
        dimmingManager.dimmingStyle == .blur || dimmingManager.dimmingStyle == .dimAndBlur
    }

    var body: some View {
        VStack(spacing: 0) {
            // Dim controls
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Dim", isOn: Binding(
                    get: { isDimEnabled },
                    set: { newValue in
                        if newValue {
                            if isBlurEnabled {
                                dimmingManager.dimmingStyle = .dimAndBlur
                            } else {
                                dimmingManager.dimmingStyle = .dim
                            }
                        } else {
                            // Allow turning off dim even if blur is off
                            dimmingManager.dimmingStyle = isBlurEnabled ? .blur : .none
                        }
                    }
                ))
                .toggleStyle(.switch)

                // Always render slider area, just hide with opacity
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Intensity")
                            .font(.caption)
                        Spacer()
                        Text("\(Int(dimmingManager.intensity * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $dimmingManager.intensity, in: 0.05...0.95)
                }
                .opacity(isDimEnabled ? 1 : 0)
                .frame(height: isDimEnabled ? nil : 0)
                .clipped()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .animation(.easeInOut(duration: 0.15), value: isDimEnabled)

            Divider()

            // Blur controls
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Blur", isOn: Binding(
                    get: { isBlurEnabled },
                    set: { newValue in
                        if newValue {
                            if isDimEnabled {
                                dimmingManager.dimmingStyle = .dimAndBlur
                            } else {
                                dimmingManager.dimmingStyle = .blur
                            }
                        } else {
                            // Allow turning off blur even if dim is off
                            dimmingManager.dimmingStyle = isDimEnabled ? .dim : .none
                        }
                    }
                ))
                .toggleStyle(.switch)

                // Always render slider area, just hide with opacity
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Intensity")
                            .font(.caption)
                        Spacer()
                        Text("\(Int(dimmingManager.blurRadius * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $dimmingManager.blurRadius, in: 0.0...1.0)
                }
                .opacity(isBlurEnabled ? 1 : 0)
                .frame(height: isBlurEnabled ? nil : 0)
                .clipped()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .animation(.easeInOut(duration: 0.15), value: isBlurEnabled)

            Divider()

            // Settings & Quit
            HStack(spacing: 12) {
                Button("Settings...") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 220)
    }
}
