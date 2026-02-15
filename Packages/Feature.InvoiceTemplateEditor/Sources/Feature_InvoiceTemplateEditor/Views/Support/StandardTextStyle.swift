import SwiftUI

struct StandardTextStyle: ViewModifier {
    let component: InvoiceComponent
    let baseFontSize: CGFloat

    func body(content: Content) -> some View {
        content
            .font(component.style.fontFamily(baseFontSize, component.style.fontWeightValue))
            .foregroundColor(component.style.textColorSwiftUI)
            .opacity(component.style.textOpacity)
            .multilineTextAlignment(component.style.textAlignment.swiftUIAlignment)
            .lineSpacing(component.style.lineSpacing)
            .tracking(component.style.letterSpacing)
            .underline(component.style.textUnderline)
            .strikethrough(component.style.textStrikethrough)
    }
}

extension View {
    func standardTextStyle(component: InvoiceComponent, baseFontSize: CGFloat) -> some View {
        modifier(StandardTextStyle(component: component, baseFontSize: baseFontSize))
    }
}
