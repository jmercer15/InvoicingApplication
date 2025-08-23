//
//  DashboardUIComponents.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//


import SwiftUI

// MARK: - Small UI Components

struct MiniMetricCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    @State private var isHovered = false
    @State private var animateValue = false

    var body: some View {
        VStack(spacing: 12) {
            // Enhanced icon with glow effect
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(isHovered ? 0.4 : 0.2),
                                color.opacity(isHovered ? 0.2 : 0.1),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .scaleEffect(isHovered ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isHovered)

                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(isHovered ? 0.3 : 0.2),
                                color.opacity(isHovered ? 0.2 : 0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(isHovered ? 0.6 : 0.4), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.3), radius: isHovered ? 6 : 3)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .scaleEffect(animateValue ? 1.1 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animateValue)
            }

            // Enhanced text section
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(animateValue ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: animateValue)

                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                // Main background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHovered ? 0.12 : 0.08),
                                .white.opacity(isHovered ? 0.08 : 0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Enhanced border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(isHovered ? 0.6 : 0.4),
                                color.opacity(isHovered ? 0.3 : 0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )

                // Inner highlight
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(isHovered ? 0.15 : 0.08), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
            }
        )
        .compositingGroup()
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .shadow(
            color: color.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateValue = true
            }
        }
    }
}

struct PerformanceIndicator: View {
    let title: String
    let value: Double
    let format: PerformanceFormat
    let color: Color
    @State private var isHovered = false
    @State private var animateValue = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Enhanced header
            HStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(isHovered ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            // Enhanced value section
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formattedValue)
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(color)
                    .scaleEffect(animateValue ? 1.05 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: animateValue)

                if format == .percentage {
                    // Enhanced trend indicator
                    HStack(spacing: 3) {
                        Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .foregroundColor(value >= 0 ? .green : .red)

                        Text(value >= 0 ? "Good" : "Down")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(value >= 0 ? .green : .red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill((value >= 0 ? Color.green : Color.red).opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(
                                        (value >= 0 ? Color.green : Color.red).opacity(0.3),
                                        lineWidth: 1)
                            )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                // Main background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHovered ? 0.12 : 0.08),
                                .white.opacity(isHovered ? 0.08 : 0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Enhanced border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(isHovered ? 0.6 : 0.4),
                                color.opacity(isHovered ? 0.3 : 0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )

                // Inner glow
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(isHovered ? 0.15 : 0.08), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
            }
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .shadow(
            color: color.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animateValue = true
            }
        }
        .appInteractiveCursor()
    }

    private var formattedValue: String {
        switch format {
        case .percentage:
            return "\(Int(value))%"
        case .currency:
            return NumberFormatter.currency.string(from: NSNumber(value: value)) ?? "$0"
        case .number:
            return "\(Int(value))"
        }
    }
}

struct ProgressMetricView: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color
    @State private var isHovered = false
    @State private var animateProgress = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Enhanced header
            HStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isHovered ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.95), .white.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                // Enhanced percentage display
                HStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(color)

                    if progress >= 0.8 {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(color.opacity(0.4), lineWidth: 1)
                        )
                )
            }

            // Enhanced progress bar
            VStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.15))
                        .frame(height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )

                    // Progress fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color,
                                    color.opacity(0.8),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: CGFloat(animateProgress ? progress : 0) * 200, height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(color.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: color.opacity(0.5), radius: 2)
                        .animation(.easeInOut(duration: 1.0), value: animateProgress)
                }
                .frame(height: 8)

                // Progress indicators
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        let threshold = Double(index + 1) * 0.2
                        Circle()
                            .fill(progress >= threshold ? color : .white.opacity(0.3))
                            .frame(width: 4, height: 4)
                            .scaleEffect(progress >= threshold ? 1.2 : 1.0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8).delay(
                                    Double(index) * 0.1), value: animateProgress)

                        if index < 4 {
                            Spacer()
                        }
                    }
                }
            }

            // Enhanced value display
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))

                    Text(NumberFormatter.currency.string(from: NSNumber(value: current)) ?? "$0")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Target")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))

                    Text(NumberFormatter.currency.string(from: NSNumber(value: target)) ?? "$0")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color.opacity(0.9))
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                // Main background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHovered ? 0.12 : 0.08),
                                .white.opacity(isHovered ? 0.08 : 0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Enhanced border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(isHovered ? 0.6 : 0.4),
                                color.opacity(isHovered ? 0.3 : 0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )

                // Inner glow
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(isHovered ? 0.15 : 0.08), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: color.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateProgress = true
            }
        }
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }
}

struct TotalHoursVisualization: View {
    let title: String
    let hours: Double
    let color: Color
    @State private var isHovered = false
    @State private var animateValue = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Enhanced header
            HStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(isHovered ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                // Hours icon
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(color.opacity(0.8))
            }
            
            // Enhanced value section
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formattedHours)
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(color)
                    .scaleEffect(animateValue ? 1.05 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: animateValue)
                
                Text("hours")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Hours visualization bar
            VStack(spacing: 6) {
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.15))
                        .frame(height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Hours fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color,
                                    color.opacity(0.8),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: CGFloat(animateValue ? min(hours / 160.0, 1.0) : 0) * 200, height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(color.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: color.opacity(0.5), radius: 2)
                        .animation(.easeInOut(duration: 1.0), value: animateValue)
                }
                .frame(height: 8)
                
                // Hours scale indicators
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        let threshold = Double(index + 1) * 32.0 // 160 hours / 5 segments
                        Circle()
                            .fill(hours >= threshold ? color : .white.opacity(0.3))
                            .frame(width: 4, height: 4)
                            .scaleEffect(hours >= threshold ? 1.2 : 1.0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.1),
                                value: animateValue
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            ZStack {
                // Main background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHovered ? 0.12 : 0.08),
                                .white.opacity(isHovered ? 0.08 : 0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Enhanced border
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(isHovered ? 0.6 : 0.4),
                                color.opacity(isHovered ? 0.3 : 0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )
                
                // Inner glow
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(isHovered ? 0.15 : 0.08), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .padding(1)
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(
            color: color.opacity(isHovered ? 0.2 : 0.1),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateValue = true
            }
        }
    }
    
    private var formattedHours: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: hours)) ?? "0.0"
    }
}
