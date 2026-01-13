import SwiftUI

struct AvatarLabelView: View {
    let emoji: String
    @ObservedObject var avatarManager: AvatarManager
    let currentAvatarEmoji: String?
    
    var body: some View {
        if avatarManager.isDualAvatarMode {
            dualAvatarLabel
        } else {
            singleAvatarLabel
        }
    }
    
    @ViewBuilder
    private var dualAvatarLabel: some View {
        if avatarManager.selectedFirstAvatar == emoji {
            Text("第一个")
                .font(.caption)
                .foregroundColor(.blue)
                .fontWeight(.medium)
        } else if avatarManager.selectedSecondAvatar == emoji {
            Text("第二个")
                .font(.caption)
                .foregroundColor(.purple)
                .fontWeight(.medium)
        } else if !avatarManager.isAvatarOwned(emoji) {
            Text("未拥有")
                .font(.caption)
                .foregroundColor(.gray)
                .fontWeight(.medium)
        }
    }
    
    @ViewBuilder
    private var singleAvatarLabel: some View {
        if currentAvatarEmoji == emoji {
            Text("当前使用")
                .font(.caption)
                .foregroundColor(.green)
                .fontWeight(.medium)
        } else if !avatarManager.isAvatarOwned(emoji) {
            Text("未拥有")
                .font(.caption)
                .foregroundColor(.gray)
                .fontWeight(.medium)
        }
    }
}

