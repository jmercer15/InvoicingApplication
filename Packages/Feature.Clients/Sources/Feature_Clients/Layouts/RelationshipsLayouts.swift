import SwiftUI
import SharedUI
import Data

// MARK: - Navigation Group Card
struct RelationshipGroupCard: View {
    let node: TreeItem
    let count: Int
    var isListStyle: Bool = false
    let onSelect: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var tint: Color {
        node.id.contains("client") ? .blue :
        node.id.contains("payee") ? .orange :
        node.id.contains("plan") ? .green : .gray
    }
    
    private var iconName: String {
        node.id.contains("client") ? "person.2" :
        node.id.contains("payee") ? "person.text.rectangle" :
        node.id.contains("plan") ? "briefcase" : "square.grid.2x2"
    }
    
    var body: some View {
        Button(action: onSelect) {
            cardBody
                .glassEffect(.regular.interactive(true), in: cardShape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: isListStyle ? 12 : 20, style: .continuous)
    }

    @ViewBuilder
    private var cardBody: some View {
        Group {
            if isListStyle {
                listLayout
            } else {
                gridLayout
            }
        }
        .contentShape(cardShape)
    }
    
    private var listLayout: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(tint)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(node.subtitle ?? "Group")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(count)")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundColor(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.1))
                .clipShape(Capsule())
            
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundColor(tint.opacity(0.7))
        }
        .padding(12)
    }
    
    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(tint)
                    )
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(node.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                Text(node.subtitle ?? "Group")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Browse Group")
                    .font(.caption.weight(.medium))
                    .foregroundColor(tint)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(tint.opacity(0.7))
            }
            .padding(.top, 8)
        }
        .padding(18)
    }
}

// MARK: - Entity Card
struct RelationshipCard: View {
    let title: String
    let subtitle: String?
    let entityType: String // "client", "payee", "planManager"
    let status: String?
    let isSelected: Bool
    var isListStyle: Bool = false
    let onSelect: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var tint: Color {
        switch entityType {
        case "client": return .blue
        case "payee": return .orange
        case "planManager": return .green
        default: return .gray
        }
    }
    
    private var iconName: String {
        switch entityType {
        case "client": return "person.crop.circle"
        case "payee": return "person.text.rectangle"
        case "planManager": return "briefcase"
        default: return "doc"
        }
    }
    
    private var statusColor: Color {
        guard let status = status?.lowercased() else { return .secondary }
        switch status {
        case "active": return .green
        case "inactive": return .gray
        case "archived": return .orange
        default: return .secondary
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            cardBody
                .glassEffect(.regular.interactive(true), in: cardShape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: isListStyle ? 12 : 16, style: .continuous)
    }

    @ViewBuilder
    private var cardBody: some View {
        Group {
            if isListStyle {
                listLayout
            } else {
                gridLayout
            }
        }
        .contentShape(cardShape)
    }
    
    private var listLayout: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(tint.opacity(0.8))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let status = status {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(status)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(tint)
                    .font(.subheadline)
            }
        }
        .padding(12)
    }
    
    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let sub = subtitle {
                        Text(sub)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(tint.opacity(0.8))
            }
            
            Spacer(minLength: 0)
            
            HStack {
                if let status = status {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(status)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(tint)
                }
            }
        }
        .padding(16)
    }
}
