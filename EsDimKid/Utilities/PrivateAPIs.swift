import Foundation
import QuartzCore
import AppKit

// MARK: - CGS Private API declarations for window tags

private let kCGSNeverFlattenSurfacesDuringSwipesTagBit: Int32 = 1 << 23

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSSetWindowTags")
private func CGSSetWindowTags(_ cid: Int32, _ wid: Int32, _ tags: UnsafePointer<Int32>, _ tagSize: Int32) -> Int32

// MARK: - Private API Helpers for CABackdropLayer blur

enum BackdropLayerHelper {
    // CAFilter constants
    static let kCAFilterGaussianBlur = "gaussianBlur"
    static let kCAFilterColorSaturate = "colorSaturate"

    /// Creates a CAFilter using private API
    static func createFilter(type: String) -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") else { return nil }

        let selector = NSSelectorFromString("filterWithType:")
        guard filterClass.responds(to: selector) else { return nil }

        let result = (filterClass as AnyObject).perform(selector, with: type)
        return result?.takeUnretainedValue() as? NSObject
    }

    /// Creates a CABackdropLayer for blur effect with behind-window blending
    static func createBackdropLayer() -> CALayer? {
        guard let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type else {
            return nil
        }

        let layer = backdropClass.init()

        // Configure backdrop layer properties
        layer.setValue(true, forKey: "allowsGroupBlending")
        layer.setValue(true, forKey: "allowsGroupOpacity")
        layer.setValue(false, forKey: "allowsEdgeAntialiasing")
        layer.setValue(true, forKey: "disablesOccludedBackdropBlurs")
        layer.setValue(true, forKey: "ignoresOffscreenGroups")
        layer.setValue(false, forKey: "allowsInPlaceFiltering")
        layer.setValue(1.0, forKey: "scale")  // Full resolution - will be adjusted dynamically
        layer.setValue(0.0, forKey: "bleedAmount")  // Will be adjusted dynamically

        // Critical for behind-window blending
        layer.setValue(true, forKey: "windowServerAware")
        layer.setValue(true, forKey: "allowsSubstituteColor")
        layer.setValue(UUID().uuidString, forKey: "groupName")

        // Set up blur and saturation filters
        if let blur = createFilter(type: kCAFilterGaussianBlur),
           let saturate = createFilter(type: kCAFilterColorSaturate) {
            blur.perform(NSSelectorFromString("setDefaults"))
            blur.setValue(true, forKey: "inputNormalizeEdges")
            saturate.perform(NSSelectorFromString("setDefaults"))
            layer.setValue([blur, saturate], forKey: "filters")
        }

        return layer
    }

    /// Sets the blur radius on a backdrop layer
    static func setBlurRadius(_ layer: CALayer, radius: CGFloat) {
        layer.setValue(radius, forKeyPath: "filters.gaussianBlur.inputRadius")
    }

    /// Sets the saturation on a backdrop layer
    static func setSaturation(_ layer: CALayer, amount: CGFloat) {
        layer.setValue(amount, forKeyPath: "filters.colorSaturate.inputAmount")
    }

    /// Sets the scale (sampling resolution) on a backdrop layer
    /// 1.0 = full resolution, 0.25 = quarter resolution (more blur, better performance)
    static func setScale(_ layer: CALayer, scale: CGFloat) {
        layer.setValue(scale, forKey: "scale")
    }

    /// Sets the bleed amount (sampling extension beyond bounds)
    static func setBleedAmount(_ layer: CALayer, amount: CGFloat) {
        layer.setValue(amount, forKey: "bleedAmount")
    }
}

// MARK: - Window Configuration Helper

enum WindowBlurHelper {
    /// Configures a window for behind-window blur with CABackdropLayer
    /// This must be called AFTER adding CABackdropLayer to the window's layer tree
    static func configureWindowForBlur(_ window: NSWindow) {
        // Prevent WindowServer from flattening the layer tree after inactivity
        window.setValue(false, forKey: "shouldAutoFlattenLayerTree")

        // Toggle canHostLayersInWindowServer to force layer tree recreation
        // This is required for CABackdropLayer to work properly
        window.setValue(false, forKey: "canHostLayersInWindowServer")
        window.setValue(true, forKey: "canHostLayersInWindowServer")

        // Window must not be opaque for behind-window blending
        window.isOpaque = false
        // Use tiny alpha (not clear!) - this is required for blur to work
        window.backgroundColor = NSColor.white.withAlphaComponent(0.001)

        // Set window tag to prevent flattening during Mission Control/Spaces swipes
        applySwipeTag(to: window)
    }

    /// Applies the CGS window tag to prevent flattening during Spaces/Mission Control swipes
    /// This tag gets reset after window resize, so call this again in windowDidEndLiveResize
    static func applySwipeTag(to window: NSWindow) {
        let contextID = CGSMainConnectionID()
        let windowNumber = Int32(window.windowNumber)
        var tags: [Int32] = [0x0, kCGSNeverFlattenSurfacesDuringSwipesTagBit]
        _ = CGSSetWindowTags(contextID, windowNumber, &tags, 0x40)
    }
}
