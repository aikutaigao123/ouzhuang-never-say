import SwiftUI

struct AvatarUtils {
    // 检查头像是否已拥有
    static func isAvatarOwned(_ emoji: String, ownedAvatars: Set<String>) -> Bool {
        guard !emoji.isEmpty else { return false }
        return ownedAvatars.contains(emoji)
    }
    
    // 获取emoji透明度
    static func getEmojiOpacity(_ emoji: String, ownedAvatars: Set<String>) -> Double {
        return ownedAvatars.contains(emoji) ? 1.0 : 0.3
    }
    
    // 获取头像背景颜色
    static func getBackgroundColor(
        emoji: String,
        avatarManager: AvatarManager,
        currentAvatarEmoji: String?
    ) -> Color {
        if avatarManager.isDualAvatarMode {
            if avatarManager.selectedFirstAvatar == emoji {
                return Color.blue.opacity(0.1)
            } else if avatarManager.selectedSecondAvatar == emoji {
                return Color.purple.opacity(0.1)
            } else if avatarManager.isAvatarOwned(emoji) {
                return Color.gray.opacity(0.1)
            } else {
                return Color.gray.opacity(0.1)
            }
        } else {
            if currentAvatarEmoji == emoji {
                return Color.green.opacity(0.1)
            } else if avatarManager.isAvatarOwned(emoji) {
                return Color.blue.opacity(0.1)
            } else {
                return Color.gray.opacity(0.1)
            }
        }
    }
    
    // 获取头像边框颜色
    static func getBorderColor(
        emoji: String,
        avatarManager: AvatarManager,
        currentAvatarEmoji: String?
    ) -> Color {
        if avatarManager.isDualAvatarMode {
            if avatarManager.selectedFirstAvatar == emoji {
                return Color.blue
            } else if avatarManager.selectedSecondAvatar == emoji {
                return Color.purple
            } else if avatarManager.isAvatarOwned(emoji) {
                return Color.clear
            } else {
                return Color.clear
            }
        } else {
            if currentAvatarEmoji == emoji {
                return Color.green
            } else if avatarManager.isAvatarOwned(emoji) {
                return Color.clear
            } else {
                return Color.clear
            }
        }
    }
    
    // 获取背景视图
    static func getBackgroundView(
        emoji: String,
        avatarManager: AvatarManager,
        currentAvatarEmoji: String?
    ) -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(getBackgroundColor(emoji: emoji, avatarManager: avatarManager, currentAvatarEmoji: currentAvatarEmoji))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(getBorderColor(emoji: emoji, avatarManager: avatarManager, currentAvatarEmoji: currentAvatarEmoji), lineWidth: 2)
            )
    }
}

