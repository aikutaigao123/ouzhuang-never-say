//
//  FriendshipManager.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-01-27.
//  标准好友关系管理器 - 基于LeanCloud REST API
//
//  🎯 符合 LeanCloud 好友关系开发指南
//  实现互为好友关系功能（需要双方互相确认）
//  
//  核心表结构：
//  - _FriendshipRequest 表：存储所有好友申请，status 字段（pending/accepted/declined）
//  - _Followee 表：存储好友关系，friendStatus 字段（true 表示双向好友）
//
//  主要功能：
//  1. 发送好友申请：创建 _FriendshipRequest 记录，status 为 pending
//  2. 接受好友申请：更新 _FriendshipRequest 的 status 为 accepted，在 _Followee 表建立双向好友关系
//  3. 拒绝好友申请：更新 _FriendshipRequest 的 status 为 declined
//  4. 删除好友申请：删除 _FriendshipRequest 记录
//  5. 查询好友列表：查询 _Followee 表，friendStatus=true 表示双向好友
//  6. 修改好友属性：更新 _Followee 表中的自定义属性列
//  7. 删除好友：只删除自己的 _Followee 记录，对方的记录保留
//

import Foundation
import LeanCloud
import UIKit

// FriendshipRequest 数据模型已移动到 Models/FriendshipRequest.swift

/**
 * 标准好友关系管理器
 * 基于LeanCloud REST API实现好友关系功能
 */
class FriendshipManager: ObservableObject {
    static let shared = FriendshipManager()
    
    // MARK: - 属性
    @Published var friendshipRequests: [FriendshipRequest] = []
    @Published var friends: [UserInfo] = []
    @Published var isLoading = false
    @Published var lastError: Error?
    
    // LeanCloud配置
    let config = Configuration.shared // 🎯 修改：改为 internal，允许 extension 访问
    
    private init() {}
    
    // searchUsers 方法已移动到 FriendshipManager+UserSearch.swift
    
    // 好友申请管理方法已移动到 FriendshipManager+RequestManagement.swift
    
    // 好友列表管理方法已移动到 FriendshipManager+FriendsList.swift
}

// 计算属性已移动到 FriendshipManager+ComputedProperties.swift

// 好友申请相关 API 已移动到 FriendshipManager+RequestAPI.swift

// 好友列表相关 API 已移动到 FriendshipManager+FriendsListAPI.swift