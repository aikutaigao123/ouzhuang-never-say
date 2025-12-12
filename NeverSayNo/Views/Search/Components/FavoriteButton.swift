import SwiftUI

struct FavoriteButton: View {
    let userId: String
    let isFavorited: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .foregroundColor(isFavorited ? .red : .gray)
                .font(.system(size: 16))
                .scaleEffect(isFavorited ? 1.26 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isFavorited)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(isFavorited ? "已喜欢" : "喜欢")
        .accessibilityHint(isFavorited ? "点击取消喜欢" : "点击喜欢此用户")
    }
}
