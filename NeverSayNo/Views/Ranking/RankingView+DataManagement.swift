import SwiftUI
import CoreLocation

// MARK: - RankingView Data Management Extension
extension RankingView {
    
    // 预加载上传数据（不显示确认对话框）
    func preloadUploadData() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        guard let location = locationManager.location else {
            return
        }
        
        // 获取设备标识符
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 获取用户信息
        let userId = currentUser.userId
        let userName = currentUser.fullName
        let loginType = currentUser.loginType.toString()
        let userEmail = currentUser.email
        
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if error != nil {
            } else {
            }
            
            let tzID = placemarks?.first?.timeZone?.identifier ?? TimeZone.current.identifier
            
            // 生成设备时间字符串 - 使用ISO 8601 UTC格式
            let localDate = Date()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let deviceTime = isoFormatter.string(from: localDate)
            
            // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { fetchedAvatar, _ in
                DispatchQueue.main.async {
                    let avatar = fetchedAvatar?.isEmpty == false ? fetchedAvatar! : UserAvatarUtils.defaultAvatar(for: loginType)
                    
                    // 🎯 新增：如果查询到头像，更新 UserDefaults（用于当前用户的信息）
                    if let fetchedAvatar = fetchedAvatar, !fetchedAvatar.isEmpty {
                        let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                        if userDefaultsAvatar != fetchedAvatar {
                            UserDefaultsManager.setCustomAvatar(userId: userId, emoji: fetchedAvatar)
                        }
                    }
                    
                    // 设置上传数据
                    self.uploadUser = currentUser
                    self.uploadLocation = location
                    self.uploadData = [
                        "latitude": location.coordinate.latitude,
                        "longitude": location.coordinate.longitude,
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
                    
                    // 初始化邮箱输入框（从用户信息中获取）
                    self.editableEmail = userEmail ?? ""
                    
                    self.isDataReady = true
                    
                    // ⚖️ 法律合规：保存原始 WGS-84 坐标（仅用于内部处理）
                    // 注意：这些原始坐标不会直接上传，上传时会转换为 GCJ-02
                    self.rawLatitude = location.coordinate.latitude
                    self.rawLongitude = location.coordinate.longitude
                    
                    // ⚖️ 法律合规：将 WGS-84 坐标转换为 GCJ-02 坐标
                    // 根据《中华人民共和国测绘法》要求，UI 显示和数据上传必须使用 GCJ-02 坐标系
                    let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    
                    // ⚖️ 注意：不在预加载时显示经纬度，保持输入框为空
                    // 用户需要点击"使用当前位置"按钮才会填充经纬度
                    // self.editableLatitude = String(format: "%.6f", gcjLat)
                    // self.editableLongitude = String(format: "%.6f", gcjLon)
                    
                    // 反向地理编码当前位置（使用GCJ-02坐标）
                    self.reverseGeocodeLocation(latitude: gcjLat, longitude: gcjLon)
                }
            }
        }
    }
    
    // 准备上传数据并显示确认对话框
    func uploadCurrentLocation() {
        guard let currentUser = userManager.currentUser else {
            uploadMessage = "无法获取当前用户信息"
            showUploadAlert = true
            return
        }
        
        guard let location = locationManager.location else {
            uploadMessage = "无法获取位置信息"
            showUploadAlert = true
            return
        }
        
        // 获取设备标识符
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 获取用户信息
        let userId = currentUser.userId
        let userName = currentUser.fullName
        let loginType = currentUser.loginType.toString()
        let userEmail = currentUser.email
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if error != nil {
            } else {
            }
            
            let tzID = placemarks?.first?.timeZone?.identifier ?? TimeZone.current.identifier
            
            // 生成设备时间字符串 - 使用ISO 8601 UTC格式
            let localDate = Date()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let deviceTime = isoFormatter.string(from: localDate)
            
            // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { fetchedAvatar, _ in
                DispatchQueue.main.async {
                    let avatar = fetchedAvatar?.isEmpty == false ? fetchedAvatar! : UserAvatarUtils.defaultAvatar(for: loginType)
                    
                    // 🎯 新增：如果查询到头像，更新 UserDefaults（用于当前用户的信息）
                    if let fetchedAvatar = fetchedAvatar, !fetchedAvatar.isEmpty {
                        let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                        if userDefaultsAvatar != fetchedAvatar {
                            UserDefaultsManager.setCustomAvatar(userId: userId, emoji: fetchedAvatar)
                        }
                    }
                    
                    // 设置上传数据
                    self.uploadUser = currentUser
                    self.uploadLocation = location
                    self.uploadData = [
                        "latitude": location.coordinate.latitude,
                        "longitude": location.coordinate.longitude,
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
                    
                    // 初始化邮箱输入框（从用户信息中获取）
                    self.editableEmail = userEmail ?? ""
                    
                    self.isDataReady = true
                    self.isRefreshingSilently = false
                    
                    // ⚖️ 法律合规：保存原始 WGS-84 坐标（仅用于内部处理）
                    // 注意：这些原始坐标不会直接上传，上传时会转换为 GCJ-02
                    self.rawLatitude = location.coordinate.latitude
                    self.rawLongitude = location.coordinate.longitude
                    
                    // ⚖️ 法律合规：将 WGS-84 坐标转换为 GCJ-02 坐标
                    // 根据《中华人民共和国测绘法》要求，UI 显示和数据上传必须使用 GCJ-02 坐标系
                    let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    
                    // ⚖️ 注意：不在初始加载时显示经纬度，保持输入框为空
                    // 用户需要点击"使用当前位置"按钮才会填充经纬度
                    // self.editableLatitude = String(format: "%.6f", gcjLat)
                    // self.editableLongitude = String(format: "%.6f", gcjLon)
                    
                    // 反向地理编码当前位置（使用GCJ-02坐标）
                    self.reverseGeocodeLocation(latitude: gcjLat, longitude: gcjLon)
                    
                    // 显示确认对话框
                    self.showConfirmDialog = true
                }
            }
        }
    }
    
    // 清空上传数据
    func clearUploadData() {
        uploadUser = nil
        uploadLocation = nil
        uploadData = [:]
        showConfirmDialog = false
        isDataReady = false
        isRefreshingSilently = false
        rawLatitude = nil
        rawLongitude = nil
        editableLatitude = ""
        editableLongitude = ""
        editableAddress = ""
        editablePlaceName = ""
        editableReason = ""
        editableEmail = ""
        geocodedLatitude = nil
        geocodedLongitude = nil
        isGettingCurrentLocation = false
        geocodingError = nil
        reversedAddress = nil
        validationErrorMessage = ""
        showValidationError = false
        stopLocationUpdateTimer() // 停止定时器
        reverseGeocodeTask?.cancel() // 取消反向地理编码任务
        reverseGeocodeTask = nil
    }
}

