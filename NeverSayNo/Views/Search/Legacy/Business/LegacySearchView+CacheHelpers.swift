//
//  LegacySearchView+CacheHelpers.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024
//  Cache helper methods for LegacySearchView
//

import SwiftUI
import Foundation

// MARK: - Cache Helpers Extension
extension LegacySearchView {
    
    /// 根据用户ID获取登录类型
    func getLoginTypeForUser(userId: String) -> String? {
        return CacheHelpers.getLoginTypeForUser(userId: userId, randomMatchHistory: randomMatchHistory)
    }
    
    /// 拉取并缓存指定用户的最新头像（仅当缓存不存在时）
    func ensureLatestAvatar(userId: String?, loginType: String?) {
        CacheHelpers.ensureLatestAvatar(
            userId: userId,
            loginType: loginType,
            latestAvatars: latestAvatars
        ) { userId, avatar in
            latestAvatars[userId] = avatar
        }
    }
    
    /// 用户名解析器（优先使用缓存的最新用户名）
    func userNameResolver(userId: String?, loginType: String?) -> String? {
        return CacheHelpers.userNameResolver(userId: userId, latestUserNames: latestUserNames)
    }
}
