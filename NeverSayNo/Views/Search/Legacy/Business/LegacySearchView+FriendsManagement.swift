//
//  LegacySearchView+FriendsManagement.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024
//  Friends management logic for LegacySearchView
//

import SwiftUI
import Foundation

// MARK: - Friends Management Extension
extension LegacySearchView {
    
    /// 加载新朋友申请数量
    func loadNewFriendsCount() {
        guard userManager.currentUser != nil else { return }
        
        // 🎯 方案1：完全使用 _FriendshipRequest 表管理好友申请
        // LegacySearchView不再管理newFriendsCount，由ContentView统一管理
        // 这里不再需要查询，因为好友申请由 FriendshipManager 统一管理
    }
}
