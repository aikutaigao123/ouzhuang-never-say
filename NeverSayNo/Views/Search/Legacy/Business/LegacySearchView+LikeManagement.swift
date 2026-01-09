//
//  LegacySearchView+LikeManagement.swift
//  NeverSayNo
//
//  Created by Auto on 2025/11/11.
//

import SwiftUI
import Foundation

// MARK: - 点赞记录管理
extension LegacySearchView {
    
    // MARK: - 添加和移除点赞记录
    
    /// 添加点赞记录
    func addLikeRecord(userId: String, userName: String?, userEmail: String?, loginType: String?, userAvatar: String?, recordObjectId: String?, isRecommendation: Bool = false) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 检查是否已经点赞过（基于objectId）
        if let objectId = recordObjectId, !isLocationRecordLiked(objectId: objectId) {
            // 先更新UI状态，让点赞按钮被点亮
            let likeRecord = LikeRecord(
                userId: currentUser.userId,
                likedUserId: userId,
                likedUserName: userName,
                likedUserEmail: userEmail,
                likedUserLoginType: loginType,
                likedUserAvatar: userAvatar,
                recordObjectId: recordObjectId
            )
            likeRecords.append(likeRecord)
            saveLikeRecords()
            
            // 上传到LeanCloud
            let likeData: [String: Any] = [
                "userId": currentUser.userId,
                "likedUserId": userId,
                "likedUserName": userName ?? "",
                "likedUserEmail": userEmail ?? "",
                "likedUserLoginType": loginType ?? "",
                "likedUserAvatar": userAvatar ?? "",
                "recordObjectId": recordObjectId ?? "",
                "likeTime": ISO8601DateFormatter().string(from: Date()),
                "status": "active",
                "userLoginType": currentUser.loginType == .apple ? "apple" : "guest",
                "userName": currentUser.fullName,
                "userEmail": currentUser.email ?? "",
                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            ]
            
            LeanCloudService.shared.uploadLikeRecord(likeData: likeData) { success, error in
                DispatchQueue.main.async {
                    if success {
                        // 🔧 修复：推荐榜不更新 LocationRecord 表，只更新 Recommendation 表
                        // 但是仍然需要更新 UserDefaults，以便 isLocationRecordLiked 能正确检查状态
                        if let recordObjectId = recordObjectId, !recordObjectId.isEmpty {
                            // 保存到本地 UserDefaults（无论是否为推荐榜）
                            let likedRecordsKey = StorageKeyUtils.getLikedLocationRecordsKey(for: currentUser)
                            UserDefaultsManager.addLikedLocationRecord(recordObjectId, forKey: likedRecordsKey)
                            
                            // 🔧 修复：只有非推荐榜才更新 LocationRecord 表的点赞数
                            if !isRecommendation {
                                LeanCloudService.shared.updateLocationLikeCount(objectId: recordObjectId, increment: true) { success, error in
                                    if success {
                                        // LocationRecord点赞数更新成功
                                        LeanCloudService.shared.printLocationRecordTable()
                                        self.printLikedLocationRecords()
                                    } else {
                                        // LocationRecord点赞数更新失败，从本地移除
                                        UserDefaultsManager.removeLikedLocationRecord(recordObjectId, forKey: likedRecordsKey)
                                    }
                                }
                            } else {
                            }
                        } else {
                        }
                        
                        // 发送点赞消息给被点赞的用户
                        let currentUserAvatar = UserDefaultsManager.getCustomAvatarWithDefault(userId: currentUser.userId)
                        self.sendLikeMessage(
                            senderId: currentUser.id,
                            senderName: currentUser.fullName,
                            senderAvatar: currentUserAvatar,
                            receiverId: userId,
                            receiverName: userName ?? "未知用户",
                            receiverAvatar: userAvatar ?? "",
                            receiverLoginType: loginType ?? "guest"
                        )
                        
                    } else {
                    }
                }
            }
        } else {
            if recordObjectId != nil {
            } else {
            }
        }
    }
    
    /// 移除点赞记录
    func removeLikeRecord(userId: String, recordObjectId: String? = nil, isRecommendation: Bool = false) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 先更新UI状态，让点赞按钮被取消点亮
        // 🔧 修复：推荐榜基于 recordObjectId 移除，非推荐榜基于 likedUserId 移除
        if isRecommendation, let recordObjectId = recordObjectId, !recordObjectId.isEmpty {
            // 🎯 推荐榜：基于 recordObjectId 移除（点赞按钮对应的是推荐榜中的一条记录）
            likeRecords.removeAll { record in
                // 🔧 修复：优先匹配 recordObjectId，如果 recordObjectId 为 nil 但 likedUserId 匹配，也移除（清理旧数据）
                let matchesByRecordObjectId = record.recordObjectId == recordObjectId
                let matchesByLikedUserId = record.recordObjectId == nil && record.likedUserId == userId
                let matches = matchesByRecordObjectId || matchesByLikedUserId
                if matches {
                    if matchesByRecordObjectId {
                    } else if matchesByLikedUserId {
                    }
                }
                return matches
            }
        } else {
            // 🎯 非推荐榜：基于 likedUserId 移除（点赞按钮对应的是用户）
            likeRecords.removeAll { record in
                let matches = record.likedUserId == userId
                if matches {
                }
                return matches
            }
        }
        saveLikeRecords()
        
        // 立即发送通知，确保UI实时更新
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
        
        // 🔧 修复：推荐榜不更新 LocationRecord 表，只更新 Recommendation 表
        // 但是仍然需要从 UserDefaults 中移除记录，以便 isLocationRecordLiked 能正确检查状态
        if let recordObjectId = recordObjectId, !recordObjectId.isEmpty {
            let likedRecordsKey = StorageKeyUtils.getLikedLocationRecordsKey(for: currentUser)
            
            // 🔧 修复：无论是否为推荐榜，都需要从 UserDefaults 中移除记录
            UserDefaultsManager.removeLikedLocationRecord(recordObjectId, forKey: likedRecordsKey)
            
            // 🔧 修复：如果推荐榜的记录无法通过 recordObjectId 匹配移除，但 UserDefaults 中已移除，
            // 说明 likeRecords 数组中有旧数据（recordObjectId 为 nil），需要清理它们
            if isRecommendation {
                let likedRecordsAfter = UserDefaultsManager.getLikedLocationRecords(forKey: likedRecordsKey)
                if !likedRecordsAfter.contains(recordObjectId) {
                    // 检查 likeRecords 数组中是否还有 recordObjectId 为 nil 的记录
                    let recordsWithNilRecordObjectId = likeRecords.filter { $0.recordObjectId == nil && $0.likedUserId == userId }
                    if !recordsWithNilRecordObjectId.isEmpty {
                        let beforeCleanupCount = likeRecords.count
                        likeRecords.removeAll { record in
                            // 🔧 只清理 recordObjectId 为 nil 且 likedUserId 匹配的旧记录
                            // 这些记录可能是之前添加的，但 recordObjectId 没有正确设置
                            let shouldRemove = record.recordObjectId == nil && record.likedUserId == userId
                            if shouldRemove {
                            }
                            return shouldRemove
                        }
                        let afterCleanupCount = likeRecords.count
                        if beforeCleanupCount != afterCleanupCount {
                            saveLikeRecords()
                        }
                    }
                }
            }
            
            // 🔧 修复：只有非推荐榜才更新 LocationRecord 表的点赞数
            if !isRecommendation {
                LeanCloudService.shared.updateLocationLikeCount(objectId: recordObjectId, increment: false) { success, error in
                    if success {
                        LeanCloudService.shared.printLocationRecordTable()
                        self.printLikedLocationRecords()
                    } else {
                        // LocationRecord点赞数减少失败，重新添加到本地
                        UserDefaultsManager.addLikedLocationRecord(recordObjectId, forKey: likedRecordsKey)
                    }
                }
            } else {
            }
        } else {
        }
        
        // 从LeanCloud更新状态为cancelled
        if isRecommendation, let recordObjectId = recordObjectId, !recordObjectId.isEmpty {
            // 🎯 新增：推荐榜使用基于 recordObjectId 的取消点赞
            LeanCloudService.shared.cancelLikeRecordByObjectId(userId: currentUser.userId, recordObjectId: recordObjectId) { success, error in
                DispatchQueue.main.async {
                    if success {
                        // 推荐榜取消点赞后，刷新推荐榜列表
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshRecommendationList"), object: nil)
                    } else {
                    }
                }
            }
        } else {
            // 非推荐榜：使用基于 likedUserId 的取消点赞
            LeanCloudService.shared.cancelLikeRecord(userId: currentUser.userId, likedUserId: userId) { success, error in
                DispatchQueue.main.async {
                    if success {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - 检查点赞状态
    
    /// 检查用户是否已被点赞
    func isUserLiked(userId: String) -> Bool {
        return DataHelpers.isUserLiked(userId: userId, likeRecords: likeRecords)
    }
    
    /// 检查LocationRecord是否已被点赞（基于objectId）
    func isLocationRecordLiked(objectId: String) -> Bool {
        let result = DataHelpers.isLocationRecordLiked(objectId: objectId, currentUser: userManager.currentUser)
        return result
    }
    
    // MARK: - 点赞记录辅助函数
    
    /// 获取当前用户点赞过的所有LocationRecord的objectId
    func getLikedLocationRecordObjectIds() -> [String] {
        guard let currentUser = userManager.currentUser else { return [] }
        let likedRecordsKey = StorageKeyUtils.getLikedLocationRecordsKey(for: currentUser)
        return UserDefaultsManager.getLikedLocationRecords(forKey: likedRecordsKey)
    }
    
    /// 清除点赞的LocationRecord记录
    func clearLikedLocationRecords() {
        guard let currentUser = userManager.currentUser else { return }
        let likedRecordsKey = StorageKeyUtils.getLikedLocationRecordsKey(for: currentUser)
        UserDefaultsManager.clearLikedLocationRecords(forKey: likedRecordsKey)
    }
    
    /// 打印当前用户点赞过的LocationRecord记录
    func printLikedLocationRecords() {
        // DebugFunctions已删除
    }
}

