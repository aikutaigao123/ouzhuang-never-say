import SwiftUI

struct UserTypeLabelView: View {
    let loginType: String?
    
    var body: some View {
        HStack(spacing: 4) {
            UserTypeIcon(loginType: loginType)
            Text(userTypeText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(userTypeColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(userTypeBackgroundColor)
        )
    }
    
    private var userTypeText: String {
        switch loginType {
        case "apple": return "Apple用户"
        default: return "游客用户"
        }
    }
    
    private var userTypeColor: Color {
        switch loginType {
        case "apple": return .purple
        default: return .blue
        }
    }
    
    private var userTypeBackgroundColor: Color {
        switch loginType {
        case "apple": return Color.purple.opacity(0.1)
        default: return Color.blue.opacity(0.1)
        }
    }
}
