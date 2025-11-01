import SwiftUI
import SharedUI

struct BillingHubTheme {
    struct Palette {
        static let backgroundTop = Color(hex: "0F172A")
        static let backgroundMid = Color(hex: "111B34")
        static let backgroundBottom = Color(hex: "0A0F1C")
        static let backdropGlowStart = Color(hex: "263260")
        static let backdropGlowEnd = Color(hex: "162036")

        static let surfacePrimary = Color(hex: "151E30")
        static let surfaceSecondary = Color(hex: "101729").opacity(0.85)
        static let surfaceStroke = Color.white.opacity(0.08)

        static let cardTop = Color(hex: "1E2841")
        static let cardBottom = Color(hex: "131B2C")
        static let cardStroke = Color.white.opacity(0.10)

        static let accentPreparing = Color(hex: "8B7CFF")
        static let accentProcessing = Color(hex: "51A9FF")
        static let accentPayment = Color(hex: "38DFA4")
        static let accentHighlight = Color(hex: "5BD8FF")
        static let accentWarning = Color(hex: "FFB566")
        static let accentCritical = Color(hex: "FF6B8B")

        static let textPrimary = Color.white.opacity(0.92)
        static let textSecondary = Color.white.opacity(0.68)
        static let textMuted = Color.white.opacity(0.45)
    }

    struct Gradients {
        static var background: some View {
            ZStack {
                LinearGradient(
                    colors: [
                        Palette.backgroundTop,
                        Palette.backgroundMid,
                        Palette.backgroundBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Palette.backdropGlowStart.opacity(0.85),
                        Palette.backdropGlowEnd.opacity(0)
                    ],
                    center: .topTrailing,
                    startRadius: 120,
                    endRadius: 520
                )
                .blendMode(.screen)

                AngularGradient(
                    gradient: Gradient(colors: [
                        Palette.accentPreparing.opacity(0.18),
                        Palette.accentProcessing.opacity(0.12),
                        Palette.accentPayment.opacity(0.18),
                        Palette.accentPreparing.opacity(0.18)
                    ]),
                    center: .center,
                    angle: .degrees(140)
                )
                .blur(radius: 160)
                .opacity(0.4)
            }
        }

        static var card: LinearGradient {
            LinearGradient(
                colors: [Palette.cardTop, Palette.cardBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static func insight(for accent: Color) -> LinearGradient {
            LinearGradient(
                colors: [
                    accent.opacity(0.38),
                    accent.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var toolbar: LinearGradient {
            LinearGradient(
                colors: [
                    Palette.surfaceSecondary.opacity(0.94),
                    Palette.surfaceSecondary.opacity(0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    struct Shadows {
        static let soft = Color.black.opacity(0.45)
    }

    struct Columns {
        static let preparing = Palette.accentPreparing
        static let processing = Palette.accentProcessing
        static let payment = Palette.accentPayment
    }

    struct Typography {
        static let title = Font.system(size: 28, weight: .heavy, design: .rounded)
        static let subtitle = Font.system(size: 14, weight: .medium, design: .rounded)
        static let metricValue = Font.system(size: 30, weight: .bold, design: .rounded)
    }

    struct Animations {
        static let hover = Animation.easeInOut(duration: StyleGuide.Animations.durationShort)
        static let spring = Animation.spring(
            response: StyleGuide.Animations.springResponse,
            dampingFraction: StyleGuide.Animations.springDamping
        )
        static let interactive = Animation.interactiveSpring(
            response: StyleGuide.Animations.springResponse,
            dampingFraction: StyleGuide.Animations.springDamping,
            blendDuration: StyleGuide.Animations.durationShort
        )
    }
}

struct BillingHubBackground: View {
    var body: some View {
        BillingHubTheme.Gradients.background
            .ignoresSafeArea()
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}
