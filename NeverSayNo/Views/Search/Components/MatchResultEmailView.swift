import SwiftUI

struct MatchResultEmailView: View {
    let email: String? // 🎯 备选邮箱（来自Recommendation表或LocationRecord）
    let emailFromUserNameRecord: String? // 🎯 新增：从UserNameRecord表查询到的邮箱
    let userId: String
    let loginType: String?
    let onCopy: () -> Void
    let isFromRecommendation: Bool // 🎯 新增：是否来自推荐榜
    @State private var emailFromServer: String? = nil // 🎯 保留用于非推荐榜的备用查询
    
    // 🎯 新增：判断是否是默认邮箱格式
    private func isDefaultEmail(_ email: String?) -> Bool {
        guard let email = email, !email.isEmpty else { return false }
        let defaultDomains = ["@internal.com", "@apple.com", "@guest.com"]
        return defaultDomains.contains { email.hasSuffix($0) }
    }
    
    // 🎯 修改：推荐榜优先使用 Recommendation.userEmail
    private var displayedEmail: String? {
        var result: String?
        
        // 🎯 推荐榜：第一优先级使用记录中给到的邮箱（Recommendation.userEmail）
        if isFromRecommendation, let recommendationEmail = email, !recommendationEmail.isEmpty {
            result = recommendationEmail
        } else if let userNameRecordEmail = emailFromUserNameRecord, !userNameRecordEmail.isEmpty {
            // 🎯 第二优先级：UserNameRecord 表的邮箱（推荐榜和非推荐榜都使用）
            // 🎯 新增：推荐榜特殊处理 - 如果查询到的邮箱是默认邮箱，使用record.userEmail
            if isFromRecommendation && isDefaultEmail(userNameRecordEmail), let recommendationEmail = email, !recommendationEmail.isEmpty {
                result = recommendationEmail
            } else {
                result = userNameRecordEmail
            }
        } else if !isFromRecommendation, let serverEmail = emailFromServer, !serverEmail.isEmpty {
            // 🎯 非推荐榜：第三优先级：从服务器实时查询的邮箱（备用）
            result = serverEmail
        } else {
            // 🎯 第四优先级：使用记录中的邮箱（备选）
            result = email
        }
        
        // 🎯 新增：最后检查，如果是默认邮箱则不显示
        if let emailToCheck = result, isDefaultEmail(emailToCheck) {
            return nil
        }
        
        return result
    }
    
    // 从服务器加载邮箱 - 仅非推荐榜且UserNameRecord邮箱未加载时使用
    private func loadEmailFromServer() {
        // 🎯 如果已经有UserNameRecord的邮箱，不需要查询
        if emailFromUserNameRecord?.isEmpty == false {
            return
        }
        
        // 🎯 修改：推荐榜不需要查询服务器邮箱（因为已经在MatchResultInfoSection中查询过了）
        if isFromRecommendation {
            return
        }
        
        let uid = userId
        let loginType = loginType ?? UserTypeUtils.getLoginTypeFromUserId(uid)
        
        LeanCloudService.shared.fetchUserEmail(objectId: uid, loginType: loginType) { email, _ in
            DispatchQueue.main.async {
                if let email = email, !email.isEmpty {
                    self.emailFromServer = email
                }
            }
        }
    }
    
    var body: some View {
        let emailToDisplay = displayedEmail
        if let userEmail = emailToDisplay, !userEmail.isEmpty {
            Divider()
                .padding(.horizontal, 20)
            
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
                Text(userEmail)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .onLongPressGesture {
                        // 复制实际显示的邮箱（优先使用UserNameRecord表的邮箱）
                        UIPasteboard.general.string = userEmail
                        onCopy()
                    }
            }
            .padding(.horizontal, 20)
            .onAppear {
                // 🎯 修改：仅非推荐榜且UserNameRecord邮箱未加载时查询服务器邮箱
                loadEmailFromServer()
            }
        } else {
        }
    }
}