import SwiftUI

@main
struct EsDimKidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dimmingManager = DimmingManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(dimmingManager)
        } label: {
            Image(nsImage: MenuBarIconGenerator.icon(enabled: dimmingManager.isEnabled))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(dimmingManager)
        }
    }
}

// MARK: - Menu Bar Icon Generator

enum MenuBarIconGenerator {
    private static var cachedEnabledIcon: NSImage?
    private static var cachedDisabledIcon: NSImage?

    static func icon(enabled: Bool) -> NSImage {
        if enabled {
            if let cached = cachedEnabledIcon { return cached }
            let icon = createIcon(enabled: true)
            cachedEnabledIcon = icon
            return icon
        } else {
            if let cached = cachedDisabledIcon { return cached }
            let icon = createIcon(enabled: false)
            cachedDisabledIcon = icon
            return icon
        }
    }

    private static func createIcon(enabled: Bool) -> NSImage {
        let size: CGFloat = 18
        let imageSize = NSSize(width: size, height: size)

        let image = NSImage(size: imageSize, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }

            let padding: CGFloat = 2
            let iconRect = bounds.insetBy(dx: padding, dy: padding)
            let cornerRadius: CGFloat = 3

            // Window outline
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.5)
            let windowPath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(windowPath)
            context.strokePath()

            if enabled {
                // Right half filled (dimmed area indicator)
                let rightRect = CGRect(x: iconRect.midX, y: iconRect.minY, width: iconRect.width / 2, height: iconRect.height)
                context.setFillColor(NSColor.black.withAlphaComponent(0.4).cgColor)

                let rightPath = CGMutablePath()
                rightPath.move(to: CGPoint(x: rightRect.minX, y: rightRect.minY))
                rightPath.addLine(to: CGPoint(x: rightRect.maxX - cornerRadius, y: rightRect.minY))
                rightPath.addArc(tangent1End: CGPoint(x: rightRect.maxX, y: rightRect.minY), tangent2End: CGPoint(x: rightRect.maxX, y: rightRect.minY + cornerRadius), radius: cornerRadius)
                rightPath.addLine(to: CGPoint(x: rightRect.maxX, y: rightRect.maxY - cornerRadius))
                rightPath.addArc(tangent1End: CGPoint(x: rightRect.maxX, y: rightRect.maxY), tangent2End: CGPoint(x: rightRect.maxX - cornerRadius, y: rightRect.maxY), radius: cornerRadius)
                rightPath.addLine(to: CGPoint(x: rightRect.minX, y: rightRect.maxY))
                rightPath.closeSubpath()

                context.addPath(rightPath)
                context.fillPath()
            }

            return true
        }

        image.isTemplate = true
        return image
    }
}
