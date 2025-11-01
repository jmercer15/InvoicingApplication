//
//  FontOptions.swift
//  Feature.InvoiceTemplateEditor
//
//  Font weight and family options for UI components
//

import Foundation

// MARK: - Font Weight Options

enum FontWeightOption: String, CaseIterable, Identifiable {
    case regular = "regular"
    case light = "light"
    case medium = "medium"
    case semibold = "semibold"
    case bold = "bold"
    case heavy = "heavy"
    case black = "black"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .light: return "Light"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        case .heavy: return "Heavy"
        case .black: return "Black"
        }
    }
    
    var styleValue: String {
        return rawValue
    }
    
    init(styleValue: String) {
        self = FontWeightOption(rawValue: styleValue) ?? .regular
    }
}

// MARK: - Font Family Options

enum FontFamilyOption: String, CaseIterable, Identifiable {
    case system = "system"
    case arial = "Arial"
    case helvetica = "Helvetica"
    case times = "Times New Roman"
    case courier = "Courier New"
    case georgia = "Georgia"
    case verdana = "Verdana"
    case monaco = "Monaco"
    case menlo = "Menlo"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .arial: return "Arial"
        case .helvetica: return "Helvetica"
        case .times: return "Times New Roman"
        case .courier: return "Courier New"
        case .georgia: return "Georgia"
        case .verdana: return "Verdana"
        case .monaco: return "Monaco"
        case .menlo: return "Menlo"
        }
    }
    
    var styleValue: String {
        return rawValue
    }
    
    init(styleValue: String) {
        self = FontFamilyOption(rawValue: styleValue) ?? .system
    }
}
