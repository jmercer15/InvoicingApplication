import SwiftUI

// MARK: - Property Option Enums
// Options for property pickers in the inspector

enum LineDecoratorOption: String, CaseIterable, Identifiable {
    case none = "None"
    case arrow = "Arrow"
    case circle = "Circle"
    case square = "Square"
    
    var id: String { self.rawValue }
    
    var styleValue: LineDecorator {
        switch self {
        case .none: return .none
        case .arrow: return .arrow
        case .circle: return .circle
        case .square: return .square
        }
    }
    
    init(styleValue: LineDecorator) {
        switch styleValue {
        case .none: self = .none
        case .arrow: self = .arrow
        case .circle: self = .circle
        case .square: self = .square
        }
    }
}

// MARK: - Preview

#Preview("LineDecoratorOption - All Types") {
    VStack(spacing: 16) {
        ForEach(LineDecoratorOption.allCases) { option in
            HStack {
                Text(option.rawValue)
                    .frame(width: 60, alignment: .leading)
                Line(startDecorator: .none, endDecorator: option.styleValue, thickness: 2)
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: 80, height: 20)
            }
        }
    }
    .padding()
}
