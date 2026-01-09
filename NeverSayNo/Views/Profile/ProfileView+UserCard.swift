import SwiftUI

// 用户信息卡片布局
extension ProfileView {
    // 用户信息卡片
    var userInfoCard: some View {
        VStack(spacing: 15) {
            HStack {
                avatarView
                
                VStack(alignment: .leading, spacing: 5) {
                    userNameView
                    loginTypeView
                }
                
                Spacer()
            }
            .id("userInfoCard-\(userManager.currentUser?.id ?? "unknown")") // 🎯 添加稳定的标识符
            
            emailView
            
            // 邮箱隐私说明
            if userManager.currentUser?.loginType != .guest {
                VStack(alignment: .leading, spacing: 5) {
                    // Apple ID 用户特殊提示（只在没有邮箱时显示）
                    let isAppleUserWithoutEmail = userManager.currentUser?.loginType == .apple && userManager.currentUser?.email == nil
                    if isAppleUserWithoutEmail {
                        Text("(隐私保护)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Text("只有被你喜欢的用户或你的好友才能看到此邮箱")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("点击寻找按钮后的24小时邮箱将处于公开状态")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
        // 🔧 修复：将通知订阅移到更高层级，避免在计算属性中创建订阅导致循环
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserNameUpdated"))) { notification in
            if let userInfo = notification.userInfo,
               let newUserName = userInfo["userName"] as? String,
               let currentUserId = userManager.currentUser?.id,
               let updatedUserId = userInfo["userId"] as? String,
               updatedUserId == currentUserId {
                // 立即更新用户名显示
                self.userNameFromServer = newUserName
                
                // 清除用户名缓存，确保下次查询时获取最新数据
                LeanCloudService.shared.clearCacheForUser(currentUserId)
            }
        }
    }
}
