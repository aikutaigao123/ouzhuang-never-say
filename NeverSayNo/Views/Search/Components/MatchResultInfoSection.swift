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
    @State private var emailRetryCount: Int = 0 // 🎯 新增：邮箱重试次数（最多重试2次）
    
    // 🎯 新增：缓存24小时判断结果，避免重复计算
    @State private var cachedIsWithinOneDay: Bool? = nil
    @State private var cachedTimestamp: String? = nil
    
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
        
        // 🎯 新增：使用缓存避免重复计算
        if let cached = cachedIsWithinOneDay, cachedTimestamp == deviceTimeString {
            return cached
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // 尝试解析时间戳
        guard let deviceTime = formatter.date(from: deviceTimeString) else {
            // 如果解析失败，尝试不带毫秒的格式
            formatter.formatOptions = [.withInternetDateTime]
            guard let deviceTimeWithoutMs = formatter.date(from: deviceTimeString) else {
                // 🎯 修复：使用异步更新状态，避免在视图更新期间修改状态
                DispatchQueue.main.async {
                    self.cachedIsWithinOneDay = false
                    self.cachedTimestamp = deviceTimeString
                }
                return false
            }
            let result = isTimeWithinOneDay(deviceTimeWithoutMs, deviceTimeString: deviceTimeString)
            // 🎯 修复：使用异步更新状态，避免在视图更新期间修改状态
            DispatchQueue.main.async {
                self.cachedIsWithinOneDay = result
                self.cachedTimestamp = deviceTimeString
            }
            return result
        }
        
        let result = isTimeWithinOneDay(deviceTime, deviceTimeString: deviceTimeString)
        // 🎯 修复：使用异步更新状态，避免在视图更新期间修改状态
        DispatchQueue.main.async {
            self.cachedIsWithinOneDay = result
            self.cachedTimestamp = deviceTimeString
        }
        return result
    }
    
    // 🎯 新增：检查时间是否在1天内
    private func isTimeWithinOneDay(_ date: Date, deviceTimeString: String) -> Bool {
        let now = Date()
        let oneDayInSeconds: TimeInterval = 24 * 60 * 60 // 1天 = 86400秒
        let timeDifference = now.timeIntervalSince(date)
        let isWithin = timeDifference >= 0 && timeDifference < oneDayInSeconds
        
        // 🎯 修复：使用UTC时区格式化时间，确保显示的时间与计算一致
        let utcTimeZone = TimeZone(identifier: "UTC") ?? TimeZone.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = utcTimeZone
        
        // 🎯 优化：只在首次判断或结果变化时打印详细信息

        
        if isWithin {

        } else {
            if timeDifference < 0 {

            } else {

            }
        }

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
        
        // 🎯 重置重试次数（仅在非重试调用时重置，即forceReload为false时）
        if !forceReload {
            emailRetryCount = 0
        }
        
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
                    // 🎯 新增：查询成功，重置重试次数
                    self.emailRetryCount = 0
                } else {
                    // 🎯 修改：使用查询时保存的fallbackEmail，而不是self.record.userEmail
                    self.emailFromUserNameRecord = fallbackEmail
                    
                    // 🎯 新增：查询失败，如果fallbackEmail也为空且未达到最大重试次数，则重试
                    if (fallbackEmail == nil || fallbackEmail!.isEmpty) && self.emailRetryCount < 2 {
                        self.retryLoadEmailFromUserNameRecord()
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询邮箱（最多重试2次）
    private func retryLoadEmailFromUserNameRecord() {
        guard emailRetryCount < 2 else {

            return
        }
        
        emailRetryCount += 1
        
        // 🎯 根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = emailRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 🎯 检查是否仍然需要查询（邮箱仍为空且userId未变化）
            if self.emailFromUserNameRecord == nil || self.emailFromUserNameRecord!.isEmpty {
                if self.currentUserId == self.record.userId {
                    self.loadEmailFromUserNameRecord(forceReload: true)
                } else {

                }
            } else {

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
            // 🎯 新增：重置邮箱重试次数
            emailRetryCount = 0
            loadEmailFromUserNameRecord(forceReload: true)
            // 🎯 新增：清除缓存，重新判断24小时（使用异步避免警告）
            DispatchQueue.main.async {
                self.cachedIsWithinOneDay = nil
                self.cachedTimestamp = nil
            }
        }
        .onChange(of: record.timestamp) { oldValue, newValue in
            // 🎯 新增：当timestamp变化时，清除缓存（使用异步避免警告）
            DispatchQueue.main.async {
                self.cachedIsWithinOneDay = nil
                self.cachedTimestamp = nil
            }
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
        
        // 🎯 优化：只在关键信息变化时打印，减少重复输出

        
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
        if result {

        } else {
            if !hasEmail {

            } else if !userLikesMe {

            }
        }

        return result
    }
}