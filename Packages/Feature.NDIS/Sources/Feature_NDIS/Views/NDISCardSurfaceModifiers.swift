import SwiftUI
import SharedUI

extension View {
    /// Shared NDIS card/chip chrome: filled rounded rect + stroke + clip.
    func ndisBorderedSurface<FillStyle: ShapeStyle, StrokeStyle: ShapeStyle>(
        fill fillStyle: FillStyle,
        stroke strokeStyle: StrokeStyle,
        cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusSmall,
        lineWidth: CGFloat = ListRowTokens.defaultStrokeWidth,
        cornerStyle: RoundedCornerStyle = .continuous
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: cornerStyle)

        return background(
            shape
                .fill(fillStyle)
                .overlay(
                    shape.stroke(strokeStyle, lineWidth: lineWidth)
                )
        )
        .clipShape(shape)
    }

    /// Panel-style surface used by loading/error/summary status cards.
    func ndisPanelBorderedSurface(
        cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusMedium
    ) -> some View {
        ndisBorderedSurface(
            fill: PanelShellTokens.panelSecondaryBackground,
            stroke: StyleGuide.Colors.border,
            cornerRadius: cornerRadius
        )
    }

    /// Fill-only panel background (no stroke) for full-pane empty/error states.
    func ndisPanelFilledBackground(
        cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusLarge
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PanelShellTokens.panelSecondaryBackground)
        )
    }

    /// Tint-driven chip surface (light fill + stronger stroke of same color).
    func ndisTintedBorderedSurface(
        tint: Color,
        fillOpacity: Double = StyleGuide.Opacity.light,
        strokeOpacity: Double = StyleGuide.Opacity.strong,
        cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusSmall
    ) -> some View {
        ndisBorderedSurface(
            fill: tint.opacity(fillOpacity),
            stroke: tint.opacity(strokeOpacity),
            cornerRadius: cornerRadius
        )
    }

    /// Interactive card/chip surface that accents when focused or selected.
    func ndisInteractiveBorderedSurface(
        fill: Color,
        idleStroke: Color,
        isEmphasized: Bool,
        cornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusSmall
    ) -> some View {
        ndisBorderedSurface(
            fill: fill,
            stroke: isEmphasized ? Color.accentColor : idleStroke,
            cornerRadius: cornerRadius,
            lineWidth: isEmphasized
                ? ListRowTokens.selectedStrokeWidth
                : ListRowTokens.defaultStrokeWidth
        )
    }
}
