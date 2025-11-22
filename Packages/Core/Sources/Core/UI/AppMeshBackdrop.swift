import SwiftUI
import AppKit

/// Shared mesh-based backdrop used across major app features.
public struct AppMeshBackdrop: View {
    public init() {}

    public var body: some View {
        Group {
            if #available(macOS 14.0, iOS 17.0, *) {
                MeshGradient(
                    width: 5,
                    height: 3,
                    points: Self.meshPoints,
                    colors: Self.meshColors,
                    background: Color(NSColor.windowBackgroundColor),
                    smoothsColors: true
                )
                .blur(radius: 40)
                .opacity(0.5)
            } else {
                fallbackBackdrop
            }
        }
        .ignoresSafeArea()
    }

    private var fallbackBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(.sRGB, red: 0.16, green: 0.29, blue: 0.62, opacity: 0.3),
                    Color(.sRGB, red: 0.08, green: 0.18, blue: 0.45, opacity: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geometry in
                ZStack {
                    ellipticalGlow(
                        size: geometry.size,
                        color: Color(.sRGB, red: 0.17, green: 0.34, blue: 0.78, opacity: 0.2),
                        offset: CGSize(width: geometry.size.width * -0.28, height: geometry.size.height * -0.32)
                    )

                    ellipticalGlow(
                        size: geometry.size,
                        color: Color(.sRGB, red: 0.11, green: 0.23, blue: 0.58, opacity: 0.18),
                        offset: CGSize(width: geometry.size.width * 0.4, height: geometry.size.height * 0.18)
                    )

                    ellipticalGlow(
                        size: geometry.size,
                        color: Color(.sRGB, red: 0.14, green: 0.3, blue: 0.7, opacity: 0.16),
                        offset: CGSize(width: geometry.size.width * 0.05, height: geometry.size.height * 0.58)
                    )

                    ellipticalGlow(
                        size: geometry.size,
                        color: Color(.sRGB, red: 0.08, green: 0.2, blue: 0.55, opacity: 0.15),
                        offset: CGSize(width: geometry.size.width * -0.15, height: geometry.size.height * 0.4)
                    )
                }
                .blur(radius: 80)
            }
        }
        .ignoresSafeArea()
    }

    private func ellipticalGlow(size: CGSize, color: Color, offset: CGSize) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: size.width * 0.9, height: size.height * 0.8)
            .offset(offset)
    }

    @available(macOS 14.0, iOS 17.0, *)
    private static var meshPoints: [SIMD2<Float>] {
        [
            SIMD2(0.0, 0.0), SIMD2(0.25, 0.0), SIMD2(0.5, 0.0), SIMD2(0.75, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.55), SIMD2(0.3, 0.45), SIMD2(0.55, 0.5), SIMD2(0.8, 0.45), SIMD2(1.0, 0.55),
            SIMD2(0.0, 1.0), SIMD2(0.25, 1.0), SIMD2(0.5, 1.0), SIMD2(0.75, 1.0), SIMD2(1.0, 1.0)
        ]
    }

    @available(macOS 14.0, iOS 17.0, *)
    private static var meshColors: [Color] {
        [
            Color(.sRGB, red: 0.12, green: 0.26, blue: 0.65, opacity: 0.5),
            Color(.sRGB, red: 0.16, green: 0.32, blue: 0.74, opacity: 0.44),
            Color(.sRGB, red: 0.1, green: 0.22, blue: 0.58, opacity: 0.46),
            Color(.sRGB, red: 0.07, green: 0.16, blue: 0.45, opacity: 0.4),
            Color(.sRGB, red: 0.05, green: 0.12, blue: 0.35, opacity: 0.36),
            Color(.sRGB, red: 0.18, green: 0.33, blue: 0.78, opacity: 0.48),
            Color(.sRGB, red: 0.14, green: 0.28, blue: 0.66, opacity: 0.44),
            Color(.sRGB, red: 0.09, green: 0.2, blue: 0.54, opacity: 0.42),
            Color(.sRGB, red: 0.06, green: 0.14, blue: 0.4, opacity: 0.38),
            Color(.sRGB, red: 0.04, green: 0.1, blue: 0.3, opacity: 0.34),
            Color(.sRGB, red: 0.13, green: 0.27, blue: 0.7, opacity: 0.46),
            Color(.sRGB, red: 0.1, green: 0.22, blue: 0.58, opacity: 0.42),
            Color(.sRGB, red: 0.07, green: 0.17, blue: 0.47, opacity: 0.38),
            Color(.sRGB, red: 0.05, green: 0.12, blue: 0.36, opacity: 0.34),
            Color(.sRGB, red: 0.04, green: 0.09, blue: 0.28, opacity: 0.3)
        ]
    }
}
