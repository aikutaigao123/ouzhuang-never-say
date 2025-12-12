import SwiftUI
import CoreLocation

class SearchLocationService: ObservableObject {
    private let locationManager: LocationManager
    private let userManager: UserManager
    private let diamondManager: DiamondManager
    
    init(locationManager: LocationManager, userManager: UserManager, diamondManager: DiamondManager) {
        self.locationManager = locationManager
        self.userManager = userManager
        self.diamondManager = diamondManager
    }
    
    func performLocationSend(completion: @escaping (Bool, String) -> Void) {
        guard let location = locationManager.location else {
            completion(false, "无法获取位置信息，请重试")
            return
        }
        
        // 获取设备标识符
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 准备要发送的数据
        // 🔧 统一使用 objectId 作为 userId
        let userId = userManager.currentUser?.id ?? "unknown_user"
        let userName = userManager.currentUser?.fullName ?? "未知用户"
        let loginType: String
        switch userManager.currentUser?.loginType {
        case .apple:
            loginType = "apple"
        case .guest:
            loginType = "guest"
        case .none:
            loginType = "guest"
        }
        let userEmail = userManager.currentUser?.email
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            let tzID = placemarks?.first?.timeZone?.identifier ?? TimeZone.current.identifier
            
            // 生成设备时间字符串 - 使用ISO 8601 UTC格式
            let localDate = Date()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let deviceTime = isoFormatter.string(from: localDate)
            
            // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { fetchedAvatar, _ in
                if let fetched = fetchedAvatar, !fetched.isEmpty {
                    self.sendLocationWithAvatar(
                        location: location,
                        userId: userId,
                        userName: userName,
                        loginType: loginType,
                        userEmail: userEmail,
                        deviceID: deviceID,
                        tzID: tzID,
                        deviceTime: deviceTime,
                        avatar: fetched,
                        completion: completion
                    )
                } else {
                    // 如果服务器没有头像，使用默认头像
                    let defaultAvatar = UserAvatarUtils.defaultAvatar(for: loginType)
                    LeanCloudService.shared.createUserAvatarRecord(objectId: userId, loginType: loginType, userAvatar: defaultAvatar) { _ in
                        self.sendLocationWithAvatar(
                            location: location,
                            userId: userId,
                            userName: userName,
                            loginType: loginType,
                            userEmail: userEmail,
                            deviceID: deviceID,
                            tzID: tzID,
                            deviceTime: deviceTime,
                            avatar: defaultAvatar,
                            completion: completion
                        )
                    }
                }
            }
        }
    }
    
    // 增强版位置发送方法，包含错误处理
    func performLocationSendWithErrorHandling(completion: @escaping (Bool, String) -> Void) {
        performLocationSend { success, message in
            if success {
                completion(true, message)
            } else {
                if message.contains("API密钥配置错误") {
                    let enhancedMessage = "API配置错误：\n请检查LeanCloud配置\n\n错误详情：\(message)\n\n建议：\n1. 检查App ID和App Key是否正确\n2. 确认Server URL格式\n3. 点击'API配置检查'按钮进行诊断"
                    completion(false, enhancedMessage)
                } else {
                    completion(false, message)
                }
            }
        }
    }
    
    private func sendLocationWithAvatar(
        location: CLLocation,
        userId: String,
        userName: String,
        loginType: String,
        userEmail: String?,
        deviceID: String,
        tzID: String,
        deviceTime: String,
        avatar: String,
        completion: @escaping (Bool, String) -> Void
    ) {
        // ⚖️ 法律合规：将 WGS-84 坐标转换为 GCJ-02 坐标
        // 根据《中华人民共和国测绘法》第四十二条规定：
        // "互联网地图服务提供者应当使用经依法审核批准的地理信息，不得使用未经审核批准的地理信息。"
        // iOS CoreLocation 返回的是 WGS-84 坐标（国际标准），必须转换为 GCJ-02（国测局坐标系）后才能存储
        let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        // ⚖️ 法律合规：使用转换后的 GCJ-02 坐标（gcjLat, gcjLon）
        // ❌ 禁止使用：location.coordinate.latitude, location.coordinate.longitude（WGS-84）
        let locationData: [String: Any] = [
            "latitude": gcjLat,
            "longitude": gcjLon,
            "accuracy": location.horizontalAccuracy,
            "userId": userId,
            "userName": userName,
            "loginType": loginType,
            "userEmail": userEmail ?? "",
            "userAvatar": avatar,
            "deviceId": deviceID,
            "timezone": tzID,
            "deviceTime": deviceTime,
            "likeCount": 0
        ]
        
        // 🎯 保存LocationRecord的坐标，用于后续对比
        let locationRecordLatitude = gcjLat
        let locationRecordLongitude = gcjLon
        
        LeanCloudService.shared.sendLocation(locationData: locationData) { success, message in
            DispatchQueue.main.async {
                if success {
                    // 🎯 新增：位置发送成功后，更新 LoginRecord 表
                    if loginType == "apple" {
                        // Apple 登录需要 authData，这里使用简化版本
                        let authData: [String: Any] = [
                            "lc_apple": [
                                "uid": userId
                            ]
                        ]
                        LeanCloudService.shared.recordAppleLoginWithAuthData(
                            userId: userId,
                            userName: userName,
                            userEmail: userEmail,
                            authData: authData,
                            deviceId: deviceID
                        ) { loginRecordSuccess in
                            if loginRecordSuccess {
                            } else {
                            }
                        }
                    } else {
                        LeanCloudService.shared.recordLogin(
                            userId: userId,
                            userName: userName,
                            userEmail: userEmail,
                            loginType: loginType,
                            deviceId: deviceID
                        ) { loginRecordSuccess in
                            if loginRecordSuccess {
                            } else {
                            }
                        }
                    }
                    
                    // 🎯 新增：位置发送成功后，立即更新UserScore表的位置信息
                    // ⚖️ 法律合规：使用已转换的GCJ-02坐标（gcjLat, gcjLon）
                    // 🎯 修改：在更新UserScore前先扣除2钻石，使用扣除后的新钻石数
                    DispatchQueue.global(qos: .utility).async {
                        self.diamondManager.spendDiamonds(2) { success in
                            guard success else {
                                // 扣除钻石失败，不更新UserScore
                                return
                            }
                            
                            // 🎯 修改：totalScore 等于扣除后的新钻石数
                            let diamonds = self.diamondManager.diamonds
                            let userScore = UserScore(
                                userId: userId,
                                userName: userName,
                                userAvatar: avatar,
                                userEmail: userEmail,
                                loginType: loginType,
                                favoriteCount: 0,
                                likeCount: 0,
                                distance: nil,
                                latitude: gcjLat,
                                longitude: gcjLon,
                                totalScore: diamonds
                            )
                            
                            
                            // 🎯 对比LocationRecord和UserScore的坐标
                            let latDiff = abs(locationRecordLatitude - gcjLat)
                            let lonDiff = abs(locationRecordLongitude - gcjLon)
                            if latDiff < 0.000000001 && lonDiff < 0.000000001 {
                            } else {
                            }
                            
                            // 异步更新UserScore表的位置信息（不阻塞主流程）
                            LeanCloudService.shared.uploadUserScore(
                                userScore: userScore,
                                locationRecordLatitude: locationRecordLatitude,
                                locationRecordLongitude: locationRecordLongitude
                            ) { updateSuccess, updateError in
                                if updateSuccess {
                                } else {
                                }
                                
                                // 位置信息更新后，合并当前用户的UserScore记录
                                LeanCloudService.shared.mergeCurrentUserScoreRecords { mergeSuccess, mergeMessage in
                                    if mergeSuccess {
                                    } else {
                                    }
                                }
                            }
                        }
                    }
                    
                    // 无论UserScore更新是否成功，都返回成功状态（不阻塞匹配流程）
                    completion(true, message)
                } else {
                    completion(success, message)
                }
            }
        }
    }
}
