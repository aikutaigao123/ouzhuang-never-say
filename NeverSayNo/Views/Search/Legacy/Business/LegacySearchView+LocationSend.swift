//
//  LegacySearchView+LocationSend.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import UIKit
import CoreLocation
import LeanCloud

// MARK: - Location Send Management Extension
extension LegacySearchView {
    
    /// 继续位置发送
    func continueLocationSend() {
        if searchStartTime != nil {
        } else {
        }
        
        // 🎯 检查是否有正在进行的上传，避免多个 continueLocationSend 同时运行
        LeanCloudService.shared.uploadingLocationLock.lock()
        let isUploading = LeanCloudService.shared.isUploadingLocation
        LeanCloudService.shared.uploadingLocationLock.unlock()
        
        if isUploading {
            // 🎯 修复：当位置正在上传时，延迟检查，等待上传完成后继续执行匹配查询
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 重新检查上传状态
                LeanCloudService.shared.uploadingLocationLock.lock()
                let stillUploading = LeanCloudService.shared.isUploadingLocation
                LeanCloudService.shared.uploadingLocationLock.unlock()
                
                if !stillUploading {
                    // 位置上传已完成，继续执行匹配查询
                    self.isLoading = false
                    self.fetchRandomRecord()
                } else {
                    // 如果还在上传，再等待1秒
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        LeanCloudService.shared.uploadingLocationLock.lock()
                        let finalCheck = LeanCloudService.shared.isUploadingLocation
                        LeanCloudService.shared.uploadingLocationLock.unlock()
                        
                        if !finalCheck {
                            self.isLoading = false
                            self.fetchRandomRecord()
                        } else {
                            // 超时后强制继续，避免用户等待过久
                            LeanCloudService.shared.uploadingLocationLock.lock()
                            LeanCloudService.shared.isUploadingLocation = false
                            LeanCloudService.shared.uploadingLocationLock.unlock()
                            self.isLoading = false
                            self.fetchRandomRecord()
                        }
                    }
                }
            }
            return
        }
        
        let stepStartTime = Date()
        if let searchStart = self.searchStartTime {
            let _ = stepStartTime.timeIntervalSince(searchStart)
        } else {
        }
        
        // 优化：使用轮询检查位置是否已更新，而不是固定等待1秒
        // 如果位置已存在，立即继续；否则最多等待1.5秒
        let maxWaitTime: TimeInterval = 1.5
        let checkInterval: TimeInterval = 0.1
        let startCheckTime = Date()
        
        func checkLocation() {
            let currentTime = Date()
            let elapsed = currentTime.timeIntervalSince(startCheckTime)
            
            if let location = self.locationManager.location {
                // 位置已更新，立即继续
                let afterWaitTime = Date()
                let _ = afterWaitTime.timeIntervalSince(startCheckTime)
                if let searchStart = self.searchStartTime {
                    let _ = afterWaitTime.timeIntervalSince(searchStart)
                }
                proceedWithLocation(location)
            } else if elapsed < maxWaitTime {
                // 继续等待
                DispatchQueue.main.asyncAfter(deadline: .now() + checkInterval) {
                    checkLocation()
                }
            } else {
                // 超时，使用当前位置或报错
                let afterWaitTime = Date()
                let _ = afterWaitTime.timeIntervalSince(startCheckTime)
                if let searchStart = self.searchStartTime {
                    let _ = afterWaitTime.timeIntervalSince(searchStart)
                }
                
                if let location = self.locationManager.location {
                    proceedWithLocation(location)
                } else {
                    self.isLoading = false
                    self.resultMessage = "无法获取位置信息，请重试"
                    self.showAlert = true
                }
            }
        }
        
        // 开始检查位置
        checkLocation()
    }
    
    /// 使用位置继续发送流程
    func proceedWithLocation(_ location: CLLocation) {
        // 🎯 检查是否有正在进行的上传，避免多个 proceedWithLocation 同时运行
        LeanCloudService.shared.uploadingLocationLock.lock()
        let isUploading = LeanCloudService.shared.isUploadingLocation
        LeanCloudService.shared.uploadingLocationLock.unlock()
        
        if isUploading {
            // 🎯 重要：跳过时重置 isLoading，避免按钮一直显示"寻找中"
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        let stepStartTime = Date()
        if let searchStart = self.searchStartTime {
            let _ = stepStartTime.timeIntervalSince(searchStart)
        } else {
        }
        
        // 🎯 添加print追踪：proceedWithLocation开始
        let userId = self.userManager.currentUser?.id ?? "unknown_user"
        
        // 获取设备标识符
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 准备要发送的数据
        // 🔧 统一使用 objectId 作为 userId
        let userName = self.userManager.currentUser?.fullName ?? "未知用户"
        let loginType: String
        switch self.userManager.currentUser?.loginType {
        case .apple:
            loginType = "apple"
        case .guest:
            loginType = "guest"
        case .none:
            loginType = "guest"
        }
        let userEmail = self.userManager.currentUser?.email
        
        let geocodeStartTime = Date()
        if let searchStart = self.searchStartTime {
            let _ = geocodeStartTime.timeIntervalSince(searchStart)
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if error != nil {
            } else {
            }
            let geocodeEndTime = Date()
            let _ = geocodeEndTime.timeIntervalSince(geocodeStartTime)
            
            if let searchStart = self.searchStartTime {
                let _ = geocodeEndTime.timeIntervalSince(searchStart)
            }
                
                let tzID = placemarks?.first?.timeZone?.identifier ?? TimeZone.current.identifier

                // 判断是否在中国境内

                // 生成设备时间字符串 - 使用ISO 8601 UTC格式
                let localDate = Date()
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let deviceTime = isoFormatter.string(from: localDate)

                let avatarStartTime = Date()
                if let searchStart = self.searchStartTime {
                    let _ = avatarStartTime.timeIntervalSince(searchStart)
                }
                
                // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
                LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { fetchedAvatar, _ in
                    let avatarEndTime = Date()
                    let _ = avatarEndTime.timeIntervalSince(avatarStartTime)
                    
                    if let searchStart = self.searchStartTime {
                        let _ = avatarEndTime.timeIntervalSince(searchStart)
                    }

                    if let fetched = fetchedAvatar, !fetched.isEmpty {
                        // ⚖️ 法律合规：将 WGS-84 坐标转换为 GCJ-02 坐标
                        // 根据《中华人民共和国测绘法》第四十二条规定，不得直接使用未经审核批准的地理信息
                        // iOS CoreLocation 返回的是 WGS-84 坐标，必须转换为 GCJ-02（国测局坐标系）后才能存储
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
                            "userAvatar": fetched,
                            "deviceId": deviceID,
                            "timezone": tzID,
                            "deviceTime": deviceTime,
                            "likeCount": 0
                        ]

                        #if DEBUG
                        if let pretty = try? JSONSerialization.data(withJSONObject: locationData, options: [.prettyPrinted]),
                           let _ = String(data: pretty, encoding: .utf8) {
                        }
                        #endif

                        let sendLocationStartTime = Date()
                        if let searchStart = self.searchStartTime {
                            let _ = sendLocationStartTime.timeIntervalSince(searchStart)
                        }
                        
                        LeanCloudService.shared.sendLocation(locationData: locationData) { success, message in
                            let sendLocationEndTime = Date()
                            let _ = sendLocationEndTime.timeIntervalSince(sendLocationStartTime)
                            
                            // 分析发送位置的总耗时构成
                            if let searchStart = self.searchStartTime {
                                let _ = sendLocationEndTime.timeIntervalSince(searchStart)
                            }
                            
                            DispatchQueue.main.async {
                                if success {
                                    // 🎯 新增：位置发送成功后，更新 LoginRecord 表
                                    if loginType == "apple" {
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
                                    
                                    let updateScoreStartTime = Date()
                                    if let searchStart = self.searchStartTime {
                                        let _ = updateScoreStartTime.timeIntervalSince(searchStart)
                                    }
                                    
                                    // 优化：UserScore操作改为后台异步执行，不阻塞匹配流程
                                    // 位置发送成功后，异步更新UserScore表（不等待完成）
                                    DispatchQueue.global(qos: .utility).async {
                                        self.updateUserScoreLocation(location: location, userId: userId, userName: userName, loginType: loginType, userEmail: userEmail, avatar: fetched) { updateSuccess in
                                            let updateScoreEndTime = Date()
                                            let _ = updateScoreEndTime.timeIntervalSince(updateScoreStartTime)
                                            if let searchStart = self.searchStartTime {
                                                let _ = updateScoreEndTime.timeIntervalSince(searchStart)
                                            }
                                            
                                            if updateSuccess {
                                                let mergeStartTime = Date()
                                                // UserScore表位置信息更新成功，继续合并记录
                                                LeanCloudService.shared.mergeCurrentUserScoreRecords { mergeSuccess, mergeMessage in
                                                    let mergeEndTime = Date()
                                                    let _ = mergeEndTime.timeIntervalSince(mergeStartTime)
                                                    if let searchStart = self.searchStartTime {
                                                        let _ = mergeEndTime.timeIntervalSince(searchStart)
                                                    }
                                                    // UserScore操作完成（后台执行，不影响匹配流程）
                                                }
                                            }
                                        }
                                    }
                                    
                                    // 立即继续匹配流程，不等待UserScore操作完成
                                    DispatchQueue.main.async {
                                        self.isLoading = false
                                        
                                        let fetchRecordStartTime = Date()
                                        if let searchStart = self.searchStartTime {
                                            let _ = fetchRecordStartTime.timeIntervalSince(searchStart)
                                        }
                                        
                                        // 关键修复：调用fetchRandomRecord来扣除钻石并获取匹配结果
                                        self.fetchRandomRecord()
                                    }
                                } else {
                                    self.isLoading = false
                                    if message.contains("API密钥配置错误") {
                                        self.resultMessage = "API配置错误：\n请检查LeanCloud配置\n\n错误详情：\(message)\n\n建议：\n1. 检查App ID和App Key是否正确\n2. 确认Server URL格式\n3. 点击'API配置检查'按钮进行诊断"
                                    } else {
                                        self.resultMessage = message
                                    }
                                    self.showAlert = true
                                }
                            }
                        }
                    } else {
                        // 如果服务器没有头像，使用默认头像
                        let defaultAvatar = UserAvatarUtils.defaultAvatar(for: loginType)
                        #if DEBUG
                        #endif
                        LeanCloudService.shared.createUserAvatarRecord(objectId: userId, loginType: loginType, userAvatar: defaultAvatar) { _ in
                            // ⚖️ 法律合规：将 WGS-84 坐标转换为 GCJ-02 坐标
                            // 根据《中华人民共和国测绘法》第四十二条规定，不得直接使用未经审核批准的地理信息
                            // iOS CoreLocation 返回的是 WGS-84 坐标，必须转换为 GCJ-02（国测局坐标系）后才能存储
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
                                "deviceId": deviceID,
                                "timezone": tzID,
                                "deviceTime": deviceTime,
                                "likeCount": 0
                            ]

                            #if DEBUG
                            if let pretty = try? JSONSerialization.data(withJSONObject: locationData, options: [.prettyPrinted]),
                               let _ = String(data: pretty, encoding: .utf8) {
                            }
                            #endif

                            LeanCloudService.shared.sendLocation(locationData: locationData) { success, message in
                                DispatchQueue.main.async {
                                    self.isLoading = false
                                    if success {
                                        // 🎯 新增：位置发送成功后，更新 LoginRecord 表
                                        if loginType == "apple" {
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
                                        
                                        self.fetchRandomRecord()
                                    } else {
                                        if message.contains("API密钥配置错误") {
                                            self.resultMessage = "API配置错误：\n请检查LeanCloud配置\n\n错误详情：\(message)\n\n建议：\n1. 检查App ID和App Key是否正确\n2. 确认Server URL格式\n3. 点击'API配置检查'按钮进行诊断"
                                        } else {
                                            self.resultMessage = message
                                        }
                                        self.showAlert = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
}

