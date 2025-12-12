import SwiftUI

struct AvatarGridItem: View {
    let emoji: String
    @ObservedObject var avatarManager: AvatarManager
    @Binding var currentAvatarEmoji: String?
    @ObservedObject var userManager: UserManager
    let onCopyEmoji: (String) -> Void
    
        var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 50))
                .opacity(AvatarUtils.getEmojiOpacity(emoji, ownedAvatars: avatarManager.ownedAvatars))
            
            AvatarLabelView(
                emoji: emoji,
                avatarManager: avatarManager,
                currentAvatarEmoji: currentAvatarEmoji
            )
        }
        .frame(width: 100, height: 100)
        .background(AvatarUtils.getBackgroundView(
            emoji: emoji,
            avatarManager: avatarManager,
            currentAvatarEmoji: currentAvatarEmoji
        ))
        .onTapGesture {
            handleAvatarSelection(emoji)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // 调用父视图的复制回调
            onCopyEmoji(emoji)
        } onPressingChanged: { isPressing in
            if isPressing {
            } else {
            }
        }
    }
    
    private func handleAvatarSelection(_ emoji: String) {
        if avatarManager.isDualAvatarMode {
            AvatarSelectionHandler.selectDualAvatar(emoji, avatarManager: avatarManager)
        } else {
            AvatarSelectionHandler.selectAvatar(
                emoji: emoji,
                avatarManager: avatarManager,
                currentAvatarEmoji: &currentAvatarEmoji,
                userManager: userManager
            )
        }
    }
}

