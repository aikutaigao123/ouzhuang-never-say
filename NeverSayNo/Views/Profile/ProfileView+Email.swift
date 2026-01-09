import SwiftUI

// 邮箱相关功能
extension ProfileView {
    // 邮箱显示组件
    var emailView: some View {
        HStack {
            // 与用户名显示逻辑一致：优先使用从服务器查询的邮箱
            // 🎯 修改：个人信息界面中显示所有邮箱，包括默认邮箱，以便用户可以看到并修改
            let displayedEmail = emailFromServer ?? userManager.currentUser?.email
            if let email = displayedEmail, !email.isEmpty {
                Text("✉️ \(email)")
                    .font(.system(size: 17 * 2.26))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .truncationMode(.tail)
            } else {
                Text("✉️ 无")
                    .font(.system(size: 17 * 2.26))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Apple ID 用户和内部账号用户都可以编辑邮箱
            let shouldShowEditButton = userManager.currentUser?.loginType == .apple
            if shouldShowEditButton {
                Button(action: {
                    newEmail = emailFromServer ?? userManager.currentUser?.email ?? ""
                    showEditEmailInputAlert = true
                }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
        }
        .onAppear {
            // 与用户名查询逻辑一致：实时查询服务器获取邮箱
            // 🔧 统一使用 objectId 作为 userId
            guard let userId = userManager.currentUser?.id,
                  let loginType = userManager.currentUser?.loginType else {
                return
            }
            let loginTypeString = loginType == .apple ? "apple" : "guest"
            
            LeanCloudService.shared.fetchUserEmail(objectId: userId, loginType: loginTypeString) { email, _ in
                DispatchQueue.main.async {
                    if let email = email, !email.isEmpty {
                        self.emailFromServer = email
                    }
                }
            }
        }
    }
}
