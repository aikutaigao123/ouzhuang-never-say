import SwiftUI

// MARK: - Preview Card Components
extension AvatarZoomView {
    
    // 头像预览卡片视图
    struct AvatarPreviewCardView: View {
        let displayAvatar: String?
        let userManager: UserManager
        @Binding var isHeartClicked: Bool
        
        var body: some View {
            VStack(spacing: 0) {
                PreviewCardHeaderView(
                    displayAvatar: displayAvatar,
                    userManager: userManager,
                    isHeartClicked: $isHeartClicked
                )
                PreviewCardContentView(userManager: userManager)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
            )
            .padding(.horizontal, 16)
            .padding(.top, 0)
        }
    }
}
