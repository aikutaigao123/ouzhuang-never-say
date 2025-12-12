import SwiftUI

// MARK: - Preview Card Content Components
extension AvatarZoomView {
    
    // 预览卡片内容
    struct PreviewCardContentView: View {
        let userManager: UserManager
        
        var body: some View {
            VStack(spacing: 16) {
                previewCardInfoRow
                previewCardInfoText
            }
            .padding(.vertical, 31)
        }
        
        // 预览卡片信息行
        private var previewCardInfoRow: some View {
            GeometryReader { geometry in
                let availableWidth = geometry.size.width - 40
                let itemCount = 2
                let spacingWidth = CGFloat(itemCount - 1) * 20
                let estimatedItemWidth = (availableWidth - spacingWidth) / CGFloat(itemCount)
                
                let baseScale = min(1.0, estimatedItemWidth / 60)
                let deviceScale = UIScreen.main.bounds.width < 375 ? 0.65 : 1.0
                let contentScale = UIScreen.main.bounds.width < 320 ? 0.55 : 1.0
                let finalScale = baseScale * deviceScale * contentScale
                
                HStack(spacing: finalScale < 0.6 ? (finalScale < 0.3 ? 1 : (finalScale < 0.4 ? 2 : (finalScale < 0.5 ? 5 : 10))) : 20) {
                    previewCardDistanceInfo
                    previewCardTimeInfo
                }
                .scaleEffect(finalScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 80)
            .padding(.horizontal, 20)
            .clipped()
        }
        
        // 预览卡片距离信息
        private var previewCardDistanceInfo: some View {
            VStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 24))
                Text("520km13m14cm")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        
        // 预览卡片时间信息
        private var previewCardTimeInfo: some View {
            VStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 24))
                Text("2024-5-20 13:14")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        
        // 预览卡片说明文字
        private var previewCardInfoText: some View {
            VStack(spacing: 4) {
                Divider()
                    .padding(.horizontal, 20)
                
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                        Text(userManager.currentUser?.loginType == .guest ? "游客账号的个人信息卡片不会展示给其他用户" : "只有被你喜欢的用户才能看到你的邮箱")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    if userManager.currentUser?.loginType != .guest {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                            Text("点击寻找按钮后的24小时邮箱将处于公开状态")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }
}
