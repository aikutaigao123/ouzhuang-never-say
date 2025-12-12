import SwiftUI

struct MatchResultInfoSection: View {
    let record: LocationRecord
    @ObservedObject var locationManager: LocationManager
    let isUserFavoritedByMe: (String) -> Bool
    let ensureFavoriteState: () -> Void
    let onCopyEmail: () -> Void
    
    // 🎯 新增：从UserNameRecord表查询到的邮箱（用于格式检查）
    @State private var emailFromUserNameRecord: String? = nil
    @State private var isEmailLoaded: Bool = false
    @State private var currentUserId: String? = nil // 🎯 新增：用于跟踪当前的userId
    
    // 🎯 新增：判断是否来自推荐榜
    private var isFromRecommendation: Bool {
        let hasPlaceName = (record.placeName?.isEmpty == false)
        let hasReason = (record.reason?.isEmpty == false)
        return hasPlaceName || hasReason
    }
    
    // 🎯 新增：判断是否是默认邮箱格式
    private func isDefaultEmail(_ email: String?) -> Bool {
        guard let email = email, !email.isEmpty else { return false }
        
        // 检查是否是默认邮箱格式：用户名@internal.com、用户名@apple.com、用户名@guest.com
        let defaultDomains = ["@internal.com", "@apple.com", "@guest.com"]
        return defaultDomains.contains { email.hasSuffix($0) }
    }
    
    // 🎯 新增：检查deviceTime是否在1天内
    private func isDeviceTimeWithinOneDay() -> Bool {
        // 如果不是推荐榜（即来自LocationRecord表），检查deviceTime
        if isFromRecommendation {
            return false // 推荐榜不检查deviceTime
        }
        
        // 解析deviceTime（ISO 8601格式）
        let deviceTimeString = record.timestamp
        guard !deviceTimeString.isEmpty else {
            return false
        }
        
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // 尝试解析时间戳
        guard let deviceTime = formatter.date(from: deviceTimeString) else {
            // 如果解析失败，尝试不带毫秒的格式
            formatter.formatOptions = [.withInternetDateTime]
            guard let deviceTimeWithoutMs = formatter.date(from: deviceTimeString) else {
                return false
            }
            return isTimeWithinOneDay(deviceTimeWithoutMs)
        }
        
        return isTimeWithinOneDay(deviceTime)
    }
    
    // 🎯 新增：检查时间是否在1天内
    private func isTimeWithinOneDay(_ date: Date) -> Bool {
        let now = Date()
        let oneDayInSeconds: TimeInterval = 24 * 60 * 60 // 1天 = 86400秒
        let timeDifference = now.timeIntervalSince(date)
        let isWithin = timeDifference >= 0 && timeDifference < oneDayInSeconds
        
        
        return isWithin
    }
    
    // 🎯 新增：从UserNameRecord表查询邮箱（用于格式检查）
    private func loadEmailFromUserNameRecord(forceReload: Bool = false) {
        let uid = record.userId
        let fallbackEmail = record.userEmail // 🎯 新增：保存查询时的record.userEmail作为备选
        
        
        // 🎯 如果已经加载过相同的userId且不强制重新加载，则不需要重新查询
        if !forceReload && currentUserId == uid && isEmailLoaded {
            return
        }
        
        // 🎯 更新当前userId
        currentUserId = uid
        
        // 🎯 重置加载状态，表示正在加载
        isEmailLoaded = false
        emailFromUserNameRecord = nil
        
        // 🎯 使用fetchUserEmailByUserId，不限制loginType，直接从UserNameRecord表获取
        LeanCloudService.shared.fetchUserEmailByUserId(objectId: uid) { email, error in
            DispatchQueue.main.async {
                // 🎯 新增：检查查询结果是否仍然对应当前的userId（防止异步回调时userId已经变化）
                guard self.currentUserId == uid else {
                    return
                }
                
                self.isEmailLoaded = true
                if let email = email, !email.isEmpty {
                    self.emailFromUserNameRecord = email
                } else {
                    // 🎯 修改：使用查询时保存的fallbackEmail，而不是self.record.userEmail
                    self.emailFromUserNameRecord = fallbackEmail
                }
            }
        }
    }
    
    // 🎯 修改：获取用于格式检查的邮箱（优先使用UserNameRecord表的邮箱）
    private var emailForCheck: String? {
        // 如果已加载，优先使用从UserNameRecord查询到的邮箱
        if isEmailLoaded {
            // 🎯 新增：如果查询到的邮箱是默认邮箱，且是推荐榜，则使用record.userEmail（推荐榜可能使用非标准邮箱）
            if isFromRecommendation, let userNameRecordEmail = emailFromUserNameRecord, isDefaultEmail(userNameRecordEmail) {
                // 推荐榜：如果查询到的邮箱是默认邮箱，使用record.userEmail（可能是推荐榜特有的邮箱格式）
                return record.userEmail
            }
            return emailFromUserNameRecord ?? record.userEmail
        }
        // 如果未加载，先使用record.userEmail（临时值，等加载完成后再更新）
        return record.userEmail
    }
    
    var body: some View {
        VStack(spacing: 16) {
            MatchResultInfoRowView(
                record: record,
                locationManager: locationManager
            )
            
            // 🎯 修改：直接使用shouldShowEmail，这样当状态变化时会自动更新
            if shouldShowEmail {
                MatchResultEmailView(
                    email: record.userEmail, // 🎯 保留作为备选
                    emailFromUserNameRecord: emailFromUserNameRecord, // 🎯 新增：传递从UserNameRecord查询到的邮箱
                    userId: record.userId,
                    loginType: record.loginType,
                    onCopy: onCopyEmail,
                    isFromRecommendation: isFromRecommendation // 🎯 新增：传递是否来自推荐榜
                )
            } else {
            }
        }
        .padding(.vertical, 20)
        .onAppear {
            ensureFavoriteState()
            // 🎯 新增：从UserNameRecord表查询邮箱（用于格式检查）
            loadEmailFromUserNameRecord()
        }
        .onChange(of: record.userId) { oldValue, newValue in
            // 🎯 新增：当userId变化时，强制重新查询
            loadEmailFromUserNameRecord(forceReload: true)
        }
    }
    
    // 🎯 修改：使用UserNameRecord表的邮箱进行格式检查，而不是Recommendation表的邮箱
    private var shouldShowEmail: Bool {
        let emailToCheck = emailForCheck
        let hasEmail = emailToCheck?.isEmpty == false
        let isDefault = isDefaultEmail(emailToCheck)
        let isRecommendation = isFromRecommendation
        let userLikesMe = isUserFavoritedByMe(record.userId) // 🎯 修改：对方喜欢我
        
        // 🎯 新增：检查deviceTime是否在1天内（会打印详细的时间判断信息）
        let isWithinOneDay = isDeviceTimeWithinOneDay()
        
        // 🎯 新增：检查是否是默认邮箱，如果是则不显示
        if isDefault {
            return false
        }

        // 🎯 推荐榜：直接显示邮箱（如果有且不是默认邮箱）
        if isRecommendation {
            let result = hasEmail
            return result
        }

        // 🎯 非推荐榜（LocationRecord表）：如果deviceTime在1天内，显示邮箱
        if isWithinOneDay && hasEmail {
            return true
        }

        // 🎯 非推荐榜：需要检查对方是否喜欢我（有邮箱且喜欢我才显示）
        let result = userLikesMe && hasEmail
        return result
    }
}