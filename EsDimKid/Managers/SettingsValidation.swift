import Foundation

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

enum IntensityValidator {
    static let range: ClosedRange<Double> = 0.0...1.0

    static func validate(_ value: Double) -> Double {
        value.clamped(to: range)
    }
}

enum BlurRadiusValidator {
    static let range: ClosedRange<Double> = 0.0...1.0

    static func validate(_ value: Double) -> Double {
        value.clamped(to: range)
    }
}

enum AnimationDurationValidator {
    static let range: ClosedRange<Double> = 0.0...2.0

    static func validate(_ value: Double) -> Double {
        value.clamped(to: range)
    }
}
