//
//  DashboardRowComponents.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI


// MARK: - Row Components

struct EnhancedSessionRow: View {
    let session: SessionEntity
    @State private var isHovered = false
    
    // Computed duration from startTime and endTime
    private var duration: TimeInterval? {
        guard let start = session.startTime, let end = session.endTime else { return nil }
        return end.timeIntervalSince(start)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            sessionContent
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 10)
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
                RoundedRectangle(cornerRadius: 10)
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
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [
                                sessionStatusColor.opacity(isHovered ? 0.6 : 0.4),
                                sessionStatusColor.opacity(isHovered ? 0.3 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 10)
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .shadow(
                        color: sessionStatusColor.opacity(isHovered ? 0.3 : 0.1),
                        radius: isHovered ? 6 : 2,
                        x: 0,
                        y: isHovered ? 3 : 1
                    )
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            EntityNavigationContextMenu(entity: .session(
                id: session.id,
                title: session.title,
                date: session.startTime,
                clientID: session.client?.id
            ))
        }
    }

    private var statusIndicator: some View {
        VStack {
            Circle()
                .fill(sessionStatusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: sessionStatusColor.opacity(0.5), radius: 2)
            Spacer()
        }
    }

    private var sessionContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            clientAndActions
            sessionDetails
        }
    }

    private var clientAndActions: some View {
        HStack(spacing: 8) {
            if let client = session.client {
                Text(client.fullName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)
            }
            Spacer()
            NavigationRowActions(entity: .session(
                id: session.id,
                title: session.title,
                date: session.startTime,
                clientID: session.client?.id
            ))
            .opacity(isHovered ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            Text(session.status?.capitalized ?? "Scheduled")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(sessionStatusColor.opacity(0.8))
                )
        }
    }

    private var sessionDetails: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                if let startTime = session.startTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(startTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            Spacer()
            if let duration = duration {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(duration / 3600))h")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("duration")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var sessionStatusColor: Color {
        guard let status = session.status?.lowercased() else { return .blue }
        
        switch status {
        case "completed":
            return .green
        case "cancelled":
            return .red
        case "in_progress":
            return .orange
        default:
            return .blue
        }
    }
}

struct CompactActivityRow: View {
    let activity: DashboardActivity
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Enhanced activity icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                activity.color.opacity(0.6),
                                activity.color.opacity(0.3)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 12
                        )
                    )
                    .frame(width: 24, height: 24)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                
                Image(systemName: activity.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(activity.color)
            }
            
            // Enhanced content section
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(activity.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Activity type badge
                    Circle()
                        .fill(activity.color.opacity(0.8))
                        .frame(width: 4, height: 4)
                }
                
                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
            }
            
            // Enhanced time display
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(activity.color.opacity(0.8))
                
                Text(activity.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                activity.color.opacity(isHovered ? 0.6 : 0.4),
                                activity.color.opacity(isHovered ? 0.3 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .shadow(
                        color: activity.color.opacity(isHovered ? 0.2 : 0.05),
                        radius: isHovered ? 4 : 1,
                        x: 0,
                        y: isHovered ? 2 : 0.5
                    )
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct EnhancedFinancialSummaryRow: View {
    let title: String
    let amount: String
    let count: Int
    let color: Color
    let trend: Double?
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Enhanced status indicator
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(isHovered ? 0.8 : 0.6),
                                color.opacity(isHovered ? 0.4 : 0.2)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 8
                        )
                    )
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: isHovered ? 2 : 1)
                    )
                    .shadow(color: color.opacity(0.4), radius: isHovered ? 4 : 2)
                
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .scaleEffect(isHovered ? 1.2 : 1.0)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("\(count) invoices")
                    .font(.caption)
                    .foregroundColor(color.opacity(0.8))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                
                // Dynamic trend indicator
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                            .foregroundColor(trend >= 0 ? .green : .red)
                        
                        Text("\(abs(trend), specifier: "%.1f")%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(trend >= 0 ? .green : .red)
                    }
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundColor(color.opacity(0.7))
                        
                        Text("vs last month")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(isHovered ? 0.6 : 0.4),
                                color.opacity(isHovered ? 0.3 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .shadow(
                        color: color.opacity(isHovered ? 0.2 : 0.05),
                        radius: isHovered ? 4 : 1,
                        x: 0,
                        y: isHovered ? 2 : 0.5
                    )
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct UrgentItemRow: View {
    let item: UrgentItem
    @State private var isHovered = false
    @State private var pulseAnimation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Enhanced priority indicator with pulsing animation
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                item.priority.color.opacity(0.8),
                                item.priority.color.opacity(0.4)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 8
                        )
                    )
                    .frame(width: 16, height: 16)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.7 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                
                Circle()
                    .fill(item.priority.color)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: item.priority.color.opacity(0.5), radius: 4)
            }
            .onAppear {
                if item.priority == .high {
                    pulseAnimation = true
                }
            }
            
            // Content section
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Priority badge
                    if item.priority == .high {
                        Text("URGENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(item.priority.color.opacity(0.8))
                            )
                    }
                }
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Enhanced time section
            VStack(alignment: .trailing, spacing: 3) {
                Text(item.dueDate.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(item.priority.color.opacity(0.9))
                
                Text(item.dueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                
                // Time remaining indicator
                if item.dueDate < Date().addingTimeInterval(24 * 60 * 60) { // Within 24 hours
                    HStack(spacing: 2) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text("Soon")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            ZStack {
                // Primary glass background with liquid effect
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                item.priority.color.opacity(isHovered ? 0.6 : 0.4),
                                item.priority.color.opacity(isHovered ? 0.3 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.5 : 1
                    )
                
                // Inner highlight with liquid glass effect
                RoundedRectangle(cornerRadius: 8)
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
                    .shadow(
                        color: item.priority.color.opacity(isHovered ? 0.3 : 0.1),
                        radius: isHovered ? 6 : 2,
                        x: 0,
                        y: isHovered ? 3 : 1
                    )
            }
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
} 
