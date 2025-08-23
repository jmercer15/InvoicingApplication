//
//  DashboardComponents.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI


// MARK: - Enhanced UI Components

struct EnhancedDashboardSection<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    let content: Content
    @State private var isHovered = false
    
    init(title: String, icon: String, accentColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced header with gradient and better spacing
            HStack(spacing: 10) {
                // Icon with enhanced styling
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Subtle accent line
                    Rectangle()
                        .fill(accentColor.opacity(0.6))
                        .frame(width: isHovered ? 60 : 40, height: 2)
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                }
                
                Spacer()
            }
            .padding(.bottom, 2)
            
            // Content container that expands to fill available space
            VStack(alignment: .leading, spacing: 0) {
                content
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(minHeight: 250, maxHeight: .infinity)
        .padding(16)
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.12),
                                Color.white.opacity(isHovered ? 0.08 : 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Liquid glass overlay with subtle animation
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.overlay)
                
                // Enhanced border with liquid effect
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(isHovered ? 0.6 : 0.4),
                                accentColor.opacity(isHovered ? 0.3 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 2 : 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
                
                // Liquid glass shadow with depth
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear)
                    .shadow(
                        color: accentColor.opacity(isHovered ? 0.3 : 0.1),
                        radius: isHovered ? 12 : 8,
                        x: 0,
                        y: isHovered ? 6 : 4
                    )
            }
        )
        .compositingGroup()
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Navigable Dashboard Metric Card
struct NavigableDashboardMetricCard: View {
    @Environment(\.appNavigationManager) private var navigationManager
    
    let metric: DashboardMetric
    let title: String
    let value: String
    let trend: Double?
    let icon: String
    let color: Color
    let subtitle: String
    var isHighlighted: Bool = false
    var isHovered: Bool = false
    let additionalData: [String: Any]?
    let onHover: () -> Void
    
    init(metric: DashboardMetric, title: String, value: String, trend: Double?, icon: String, color: Color, subtitle: String, isHighlighted: Bool = false, isHovered: Bool = false, additionalData: [String: Any]? = nil, onHover: @escaping () -> Void) {
        self.metric = metric
        self.title = title
        self.value = value
        self.trend = trend
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.isHighlighted = isHighlighted
        self.isHovered = isHovered
        self.additionalData = additionalData
        self.onHover = onHover
    }
    
    var body: some View {
        AnimatedPremiumStatCard(
            title: title,
            value: value,
            trend: trend,
            icon: icon,
            color: color,
            subtitle: subtitle,
            isHighlighted: isHighlighted,
            isHovered: isHovered
        ) {
            // Handle both hover state and navigation
            onHover()
            navigationManager.navigateFromDashboardMetric(metric: metric, additionalData: additionalData)
        }
        .appInteractiveCursor()
    }
}

struct AnimatedPremiumStatCard: View {
    let title: String
    let value: String
    let trend: Double?
    let icon: String
    let color: Color
    let subtitle: String
    var isHighlighted: Bool = false
    var isHovered: Bool = false
    let onTap: () -> Void
    
    @State private var animateValue = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(color.opacity(isHovered ? 0.25 : 0.15))
                                .animation(.easeInOut(duration: 0.2), value: isHovered)
                        )
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                    
                    Spacer()
                    
                    if let trend = trend {
                        PremiumTrendIndicator(value: trend)
                            .scaleEffect(animateValue ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.3).delay(0.1), value: animateValue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(isHighlighted ? .title : .title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .scaleEffect(animateValue ? 1.02 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: animateValue)
                    
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(20)
            .background(
                ZStack {
                    // Primary glass background with liquid effect
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isHighlighted ? color.opacity(isHovered ? 0.15 : 0.1) : Color.white.opacity(isHovered ? 0.18 : 0.12),
                                    Color.white.opacity(isHovered ? 0.08 : 0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Liquid glass overlay with subtle animation
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .blendMode(.overlay)
                    
                    // Enhanced border with liquid effect
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    isHighlighted ? (isHovered ? color.opacity(0.6) : color.opacity(0.4)) : (isHovered ? color.opacity(0.4) : color.opacity(0.2)),
                                    Color.accentColor.opacity(isHovered ? 0.3 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHighlighted ? 2 : 1
                        )
                    
                    // Inner highlight with liquid glass effect
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.15), .clear],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                        .padding(1)
                    
                    // Liquid glass shadow with depth
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.clear)
                        .shadow(
                            color: isHighlighted ? color.opacity(0.3) : Color.black.opacity(0.4),
                            radius: isHovered ? 12 : 8,
                            x: 0,
                            y: isHovered ? 6 : 4
                        )
                }
            )
            .compositingGroup()
            .scaleEffect(isHighlighted ? (isHovered ? 1.05 : 1.02) : (isHovered ? 1.03 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHighlighted)
        }
        .buttonStyle(.plain)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateValue = true
            }
        }
    }
}

struct PremiumTrendIndicator: View {
    let value: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)
                .foregroundColor(value >= 0 ? .green : .red)
            
            Text("\(abs(value), specifier: "%.1f")%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(value >= 0 ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((value >= 0 ? Color.green : Color.red).opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke((value >= 0 ? Color.green : Color.red).opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Additional Components

struct EnhancedQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Enhanced icon with multiple layers
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(isHovered ? 0.4 : 0.2),
                                    color.opacity(isHovered ? 0.2 : 0.1),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .scaleEffect(isHovered ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                    
                    // Main icon background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(isHovered ? 0.3 : 0.2),
                                    color.opacity(isHovered ? 0.2 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(isHovered ? 0.8 : 0.5),
                                            color.opacity(isHovered ? 0.4 : 0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isHovered ? 2 : 1
                                )
                        )
                        .shadow(
                            color: color.opacity(isHovered ? 0.3 : 0.1),
                            radius: isHovered ? 8 : 4,
                            x: 0,
                            y: isHovered ? 4 : 2
                        )
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
                
                // Enhanced text section
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .background(
                ZStack {
                    // Primary glass background with liquid effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.18 : 0.12),
                                    Color.white.opacity(isHovered ? 0.08 : 0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Liquid glass overlay with subtle animation
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .blendMode(.overlay)
                    
                    // Enhanced border with liquid effect
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    color.opacity(isHovered ? 0.6 : 0.3),
                                    color.opacity(isHovered ? 0.3 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isHovered ? 1.5 : 1
                        )
                    
                    // Inner highlight with liquid glass effect
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.15), .clear],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                        .padding(1)
                    
                    // Liquid glass shadow with depth
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.clear)
                        .shadow(
                            color: color.opacity(isHovered ? 0.2 : 0.05),
                            radius: isHovered ? 12 : 4,
                            x: 0,
                            y: isHovered ? 6 : 2
                        )
                }
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .appInteractiveCursor()
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }
        }
    }
}

// Helper for press events
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}

struct EnhancedEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let color: Color
    @State private var animateIcon = false
    @State private var fadeIn = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Enhanced icon with animation
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(0.3),
                                color.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .opacity(animateIcon ? 0.8 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: animateIcon
                    )
                
                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.2),
                                color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.4), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color.opacity(0.8))
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIcon)
            }
            
            // Enhanced text section
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(color.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .opacity(fadeIn ? 1.0 : 0.0)
        .scaleEffect(fadeIn ? 1.0 : 0.9)
        .animation(.easeInOut(duration: 0.6), value: fadeIn)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                fadeIn = true
                animateIcon = true
            }
        }
    }
} 