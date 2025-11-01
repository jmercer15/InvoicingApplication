import SwiftUI

// MARK: - Property Option Enums
// Options for property pickers in the inspector

enum LineStyleOption: String, CaseIterable, Identifiable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"
    
    var id: String { self.rawValue }
    
    var styleValue: LineStyle {
        switch self {
        case .solid: return .solid
        case .dashed: return .dashed
        case .dotted: return .dotted
        }
    }
    
    init(styleValue: LineStyle) {
        switch styleValue {
        case .solid: self = .solid
        case .dashed: self = .dashed
        case .dotted: self = .dotted
        }
    }
}

enum ImageContentModeOption: String, CaseIterable, Identifiable {
    case fit = "Fit"
    case fill = "Fill"
    
    var id: String { self.rawValue }
    
    var styleValue: ImageContentMode {
        switch self {
        case .fit: return .fit
        case .fill: return .fill
        }
    }
    
    init(styleValue: ImageContentMode) {
        switch styleValue {
        case .fit: self = .fit
        case .fill: self = .fill
        }
    }
}

enum TriangleDirectionOption: String, CaseIterable, Identifiable {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    
    var id: String { self.rawValue }
    
    var styleValue: TriangleDirection {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        }
    }
    
    init(styleValue: TriangleDirection) {
        switch styleValue {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        }
    }
}

