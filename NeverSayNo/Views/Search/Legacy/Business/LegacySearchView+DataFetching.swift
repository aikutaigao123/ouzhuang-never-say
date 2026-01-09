//
//  LegacySearchView+DataFetching.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024
//  Data fetching methods for LegacySearchView
//

import SwiftUI
import Foundation

// MARK: - Data Fetching Extension
extension LegacySearchView {
    
    /// 从服务器获取数据
    func fetchDataFromServer(currentUser: UserInfo) {
        
        // 🔧 新增：fetchDataFromServer - 超详细分析
        
        // 后台异步获取数据，不阻塞UI显示
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            var fetchedFavoriteRecords: [FavoriteRecord] = []
            var fetchedUsersWhoLikedMe: [FavoriteRecord] = []

            group.enter()
            LeanCloudService.shared.fetchActiveFavoriteRecords(userId: currentUser.id) { records, error in // 🔧 统一：使用 objectId
                if let records = records {
                    fetchedFavoriteRecords = records.compactMap { FavoriteRecord(dictionary: $0) }
                }
                group.leave()
            }

            group.enter()
            LeanCloudService.shared.fetchActiveFavoriteRecords(favoriteUserId: currentUser.id) { records, error in // 🔧 统一：使用 objectId
                if let records = records {
                    fetchedUsersWhoLikedMe = records.compactMap { FavoriteRecord(dictionary: $0) }
                }
                group.leave()
            }

            group.notify(queue: .main) {
                let _ = self.favoriteRecords.map { record -> String in
                    let status = record.status ?? "nil"
                    return "\(record.favoriteUserId)(status:\(status))"
                }.joined(separator: ", ")
                let _ = self.usersWhoLikedMe.map { record -> String in
                    let status = record.status ?? "nil"
                    return "\(record.userId)(status:\(status))"
                }.joined(separator: ", ")
                
                let _ = fetchedFavoriteRecords.map { record -> String in
                    let status = record.status ?? "nil"
                    return "\(record.favoriteUserId)(status:\(status))"
                }.joined(separator: ", ")
                let _ = fetchedUsersWhoLikedMe.map { record -> String in
                    let status = record.status ?? "nil"
                    return "\(record.userId)(status:\(status))"
                }.joined(separator: ", ")
                // Update ContentView's state variables with fresh data
                self.favoriteRecords = fetchedFavoriteRecords
                self.usersWhoLikedMe = fetchedUsersWhoLikedMe
                let _ = self.favoriteRecords.map { record -> String in
                    let status = record.status ?? "nil"
                    return "\(record.favoriteUserId)(status:\(status))"
                }.joined(separator: ", ")
                let _ = self.usersWhoLikedMe.map { record -> String in
                    let status = record.status ?? "nil"
                    return "\(record.userId)(status:\(status))"
                }.joined(separator: ", ")
                
                // 缓存新获取的数据
                self.cacheFavoriteRecords(fetchedFavoriteRecords)
                self.cacheUsersWhoLikedMe(fetchedUsersWhoLikedMe)
                
                // 更新消息界面数据（也会缓存消息和好友数据）
                self.updateMessageViewData()
                
                DispatchQueue.global(qos: .userInitiated).async {
                    self.loadUsersWhoLikedMe {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                        }
                    }
                }
            }
        }
    }
    
    /// 在后台更新缓存
    func updateCachesInBackground() {
        // 后台更新缓存，不影响UI响应
        MessageButtonCacheManager.shared.updateAllCaches { success, report in
            DispatchQueue.main.async {
                if success {
                    // 从第一层缓存构建全局缓存，避免重复网络请求
                    MessageButtonCacheManager.shared.buildGlobalCacheFromLocalCache()
                    // 在缓存更新完成后清理过期缓存
                    self.cleanupCacheAfterUpdate()
                }
            }
        }
    }
    
    /// 从UserAvatarRecord表获取正确的用户头像 - 只从UserAvatarRecord表读取
    func getCorrectUserAvatar(userId: String, fallbackAvatar: String) -> String {
        return UserHelpers.getCorrectUserAvatar(userId: userId, fallbackAvatar: fallbackAvatar)
    }
}
