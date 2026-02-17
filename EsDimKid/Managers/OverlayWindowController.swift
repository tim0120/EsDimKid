import AppKit

private enum OverlayConstants {
    static let screenCornerRadius: CGFloat = 12.0
    static let windowCornerRadius: CGFloat = 10.0
    static let defaultIntensity: Double = 0.35
    static let maxBlurRadius: Double = 30.0
    static let blurPerformanceThreshold: Double = 0.3
    static let reducedScale: CGFloat = 0.25
    static let fullScale: CGFloat = 1.0
    static let saturationMultiplier: Double = 0.8
    static let maxBleedAmount: Double = 15.0
    static let bleedMultiplier: Double = 0.5
    static let blurVisibilityThreshold: Double = 0.005
    static let defaultOverlayColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
}

/// Manages overlay windows for dimming inactive areas of the screen.
/// Creates one overlay window per display, handling multi-monitor setups.
@MainActor
final class OverlayWindowController {
    private var overlayWindows: [NSScreen: OverlayWindow] = [:]
    var animationDuration: Double = 0.3

    private var isShowing = false
    private var currentIntensity: Double = OverlayConstants.defaultIntensity
    private var currentColor: NSColor = OverlayConstants.defaultOverlayColor
    private var currentDimmingStyle: DimmingStyle = .dim
    private var currentBlurRadius: Double = 0.5

    init() {
        setupOverlays()
    }

    // MARK: - Public Methods

    func show() {
        guard !isShowing else { return }
        isShowing = true

        for (_, window) in overlayWindows {
            window.orderFront(nil)
            animateFadeIn(window)
        }
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false

        for (_, window) in overlayWindows {
            animateFadeOut(window) {
                Task { @MainActor in
                    window.orderOut(nil)
                }
            }
        }
    }

    func setIntensity(_ intensity: Double) {
        currentIntensity = intensity
        for (_, window) in overlayWindows {
            window.overlayView.intensity = intensity
        }
    }

    func setColor(_ color: NSColor) {
        currentColor = color
        for (_, window) in overlayWindows {
            window.overlayView.color = color
        }
    }

    func setDimmingStyle(_ style: DimmingStyle) {
        currentDimmingStyle = style
        for (_, window) in overlayWindows {
            window.overlayView.dimmingStyle = style
        }
    }

    func setBlurRadius(_ radius: Double) {
        currentBlurRadius = radius
        for (_, window) in overlayWindows {
            window.overlayView.blurRadius = radius
        }
    }

    func updateMask(for windowFrame: CGRect?) {
        guard let frame = windowFrame else {
            // No active window - dim everything or show no mask
            for (_, window) in overlayWindows {
                window.overlayView.activeWindowFrames = []
            }
            return
        }

        updateMask(for: [frame])
    }

    func updateMask(for windowFrames: [CGRect]) {
        for (screen, window) in overlayWindows {
            // Convert frames to screen-local coordinates
            let localFrames = windowFrames.compactMap { frame -> CGRect? in
                // Check if the window intersects with this screen
                guard frame.intersects(screen.frame) else { return nil }

                // Convert to screen-local coordinates
                var localFrame = frame
                localFrame.origin.x -= screen.frame.origin.x
                localFrame.origin.y -= screen.frame.origin.y

                return localFrame
            }

            window.overlayView.activeWindowFrames = localFrames
        }
    }

    func updateForScreenChanges() {
        // Remove overlays for disconnected screens
        let currentScreens = Set(NSScreen.screens)
        for screen in overlayWindows.keys where !currentScreens.contains(screen) {
            overlayWindows[screen]?.close()
            overlayWindows.removeValue(forKey: screen)
        }

        // Add overlays for new screens
        for screen in currentScreens where overlayWindows[screen] == nil {
            let window = createOverlayWindow(for: screen)
            overlayWindows[screen] = window
            if isShowing {
                window.orderFront(nil)
            }
        }

        // Update existing overlay positions
        for (screen, window) in overlayWindows {
            window.setFrame(screen.frame, display: true)
        }
    }

    // MARK: - Private Methods

    private func setupOverlays() {
        for screen in NSScreen.screens {
            let window = createOverlayWindow(for: screen)
            overlayWindows[screen] = window
        }
    }

    private func createOverlayWindow(for screen: NSScreen) -> OverlayWindow {
        let window = OverlayWindow(screen: screen)
        window.overlayView.intensity = currentIntensity
        window.overlayView.color = currentColor
        window.overlayView.dimmingStyle = currentDimmingStyle
        window.overlayView.blurRadius = currentBlurRadius
        return window
    }

    private func animateFadeIn(_ window: OverlayWindow) {
        let shouldAnimate = animationDuration > 0 && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if shouldAnimate {
            window.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 1
            }
        } else {
            window.alphaValue = 1
        }
    }

    private func animateFadeOut(_ window: OverlayWindow, completion: @escaping @Sendable () -> Void) {
        let shouldAnimate = animationDuration > 0 && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if shouldAnimate {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 0
            }, completionHandler: completion)
        } else {
            window.alphaValue = 0
            completion()
        }
    }
}

// MARK: - OverlayWindow

class OverlayWindow: NSWindow, NSWindowDelegate {
    var overlayView: OverlayView!

    convenience init(screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.delegate = self

        overlayView = OverlayView(frame: screen.frame)

        // Configure window for basic overlay behavior
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Set window level ABOVE normal windows so overlay is visible
        // The active window will be "cut out" via masking
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) + 1)

        self.contentView = overlayView

        // Move to correct screen
        self.setFrame(screen.frame, display: true)

        // Configure window for CABackdropLayer behind-window blur
        // This MUST be called after contentView is set and backdrop layer exists
        WindowBlurHelper.configureWindowForBlur(self)
    }

    // Reapply CGS tags after live resize (they get reset)
    func windowDidEndLiveResize(_ notification: Notification) {
        WindowBlurHelper.applySwipeTag(to: self)
    }
}

// MARK: - OverlayView

class OverlayView: NSView {
    var intensity: Double = OverlayConstants.defaultIntensity {
        didSet { needsDisplay = true }
    }

    var color: NSColor = OverlayConstants.defaultOverlayColor {
        didSet { needsDisplay = true }
    }

    var activeWindowFrames: [CGRect] = [] {
        didSet {
            updateBlurMask()
            needsDisplay = true
        }
    }

    var dimmingStyle: DimmingStyle = .dim {
        didSet {
            updateBlurVisibility()
            needsDisplay = true
        }
    }

    var blurRadius: Double = 0.5 {
        didSet { updateBlurRadius() }
    }

    private var backdropLayer: CALayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = OverlayConstants.screenCornerRadius
        layer?.masksToBounds = true

        // Create backdrop layer for blur (private API)
        if let backdrop = BackdropLayerHelper.createBackdropLayer() {
            backdrop.frame = bounds
            backdrop.cornerRadius = OverlayConstants.screenCornerRadius
            backdropLayer = backdrop
            layer?.addSublayer(backdrop)

            // Set initial blur and saturation (both handled by updateBlurRadius)
            updateBlurRadius()
        }

        updateBlurVisibility()
    }

    private func updateBlurRadius() {
        guard let backdrop = backdropLayer else { return }

        // Scale: 0% = 0 blur, 100% = max blur radius
        // Using gentler curve (power of 2) for smoother low-end control
        let radius = pow(blurRadius, 2.0) * OverlayConstants.maxBlurRadius
        BackdropLayerHelper.setBlurRadius(backdrop, radius: CGFloat(radius))

        // Scale saturation from 1.0 (no change) at 0% to 1.8 at 100%
        let saturation = 1.0 + (blurRadius * OverlayConstants.saturationMultiplier)
        BackdropLayerHelper.setSaturation(backdrop, amount: CGFloat(saturation))

        // Dynamically adjust scale for performance at high blur levels
        // At low blur, use full resolution to avoid downsampling artifacts
        // At high blur, use quarter resolution for better performance
        let scale: CGFloat = blurRadius > OverlayConstants.blurPerformanceThreshold
            ? OverlayConstants.reducedScale
            : OverlayConstants.fullScale
        BackdropLayerHelper.setScale(backdrop, scale: scale)

        // Adjust bleed amount based on blur radius
        let bleed = radius > 0
            ? min(radius * OverlayConstants.bleedMultiplier, OverlayConstants.maxBleedAmount)
            : 0.0
        BackdropLayerHelper.setBleedAmount(backdrop, amount: CGFloat(bleed))

        // Update visibility
        updateBlurVisibility()
    }

    private func updateBlurVisibility() {
        // Hide blur completely when radius is effectively 0 or style doesn't include blur
        let showBlur = dimmingStyle.hasBlur && blurRadius > OverlayConstants.blurVisibilityThreshold
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdropLayer?.isHidden = !showBlur
        CATransaction.commit()
    }

    private func updateBlurMask() {
        guard let backdrop = backdropLayer else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if activeWindowFrames.isEmpty {
            // No active windows - blur entire screen
            backdrop.mask = nil
        } else {
            // Create mask with cutouts for active windows
            let maskLayer = CAShapeLayer()
            maskLayer.frame = bounds

            let path = CGMutablePath()
            // Full bounds (with rounded corners to match screen)
            path.addRoundedRect(in: bounds, cornerWidth: OverlayConstants.screenCornerRadius, cornerHeight: OverlayConstants.screenCornerRadius)
            // Cut out active windows using even-odd (with rounded corners to match macOS windows)
            for frame in activeWindowFrames {
                let clippedFrame = frame.intersection(bounds)
                if !clippedFrame.isEmpty {
                    path.addRoundedRect(in: clippedFrame, cornerWidth: OverlayConstants.windowCornerRadius, cornerHeight: OverlayConstants.windowCornerRadius)
                }
            }

            maskLayer.path = path
            maskLayer.fillRule = .evenOdd
            backdrop.mask = maskLayer
        }

        CATransaction.commit()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Clear
        context.clear(bounds)

        guard dimmingStyle.hasDim else { return }

        // Draw dim overlay with cutouts using even-odd fill
        let fillColor = color.withAlphaComponent(intensity)
        context.setFillColor(fillColor.cgColor)

        context.beginPath()

        // Rounded rect for screen bounds
        let screenPath = CGPath(roundedRect: bounds, cornerWidth: OverlayConstants.screenCornerRadius, cornerHeight: OverlayConstants.screenCornerRadius, transform: nil)
        context.addPath(screenPath)

        // Cut out active windows (with rounded corners to match macOS windows)
        for frame in activeWindowFrames {
            let clippedFrame = frame.intersection(bounds)
            if !clippedFrame.isEmpty {
                let roundedPath = CGPath(roundedRect: clippedFrame, cornerWidth: OverlayConstants.windowCornerRadius, cornerHeight: OverlayConstants.windowCornerRadius, transform: nil)
                context.addPath(roundedPath)
            }
        }

        context.fillPath(using: .evenOdd)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdropLayer?.frame = bounds
        // Update mask frame directly here (updateBlurMask has its own transaction)
        if let mask = backdropLayer?.mask {
            mask.frame = bounds
        }
        CATransaction.commit()
    }

    override var isFlipped: Bool {
        false
    }
}
