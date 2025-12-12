//
//  FriendshipLiveQueryManager.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-01-27.
//  好友关系LiveQuery实时通知管理器
//

import Foundation
import LeanCloud
import UIKit

/**
 * 好友关系LiveQuery实时通知管理器
 * 基于LeanCloud LiveQuery实现实时好友申请通知
 */
class FriendshipLiveQueryManager: ObservableObject {
    static let shared = FriendshipLiveQueryManager()
    
    // MARK: - 属性
    @Published var isConnected = false
    @Published var lastError: Error?
    
    private var friendshipRequestLiveQuery: LiveQuery?
    private var friendshipLiveQuery: LiveQuery?
    
    private init() {}
    
    // MARK: - 连接管理
    
    /**
     * 启动LiveQuery订阅
     * - Parameter currentUserId: 当前用户ID
     */
    func startSubscription(currentUserId: String) {
        
        // 订阅好友申请通知
        subscribeToFriendshipRequests(currentUserId: currentUserId)
        
        // 订阅好友关系变化通知
        subscribeToFriendshipChanges(currentUserId: currentUserId)
    }
    
    /**
     * 停止LiveQuery订阅
     */
    func stopSubscription() {
        
        friendshipRequestLiveQuery?.unsubscribe { _ in }
        friendshipLiveQuery?.unsubscribe { _ in }
        
        friendshipRequestLiveQuery = nil
        friendshipLiveQuery = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    // MARK: - 私有方法
    
    /**
     * 订阅好友申请通知
     */
    private func subscribeToFriendshipRequests(currentUserId: String) {
        do {
            let query = LCQuery(className: "_FriendshipRequest")
            
            // 使用 LeanCloud 当前用户 objectId（优先），避免把应用内部 userId 误当作 _User.objectId
            let lcObjectId = LCApplication.default.currentUser?.objectId?.value ?? currentUserId
            if lcObjectId == currentUserId {
            } else {
            }
            // 查询发给当前用户的好友申请
            query.whereKey("friend", .equalTo(LCObject(className: "_User", objectId: lcObjectId)))
            query.whereKey("status", .equalTo("pending"))
            
            let liveQuery = try LiveQuery(query: query) { [weak self] liveQuery, event in
                self?.handleFriendshipRequestEvent(event)
            }
            
            liveQuery.subscribe { [weak self] result in
                switch result {
                case .success:
                    self?.friendshipRequestLiveQuery = liveQuery
                    
                    DispatchQueue.main.async {
                        self?.isConnected = true
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.lastError = error
                        self?.isConnected = false
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.lastError = error
                self.isConnected = false
            }
        }
    }
    
    /**
     * 订阅好友关系变化通知
     */
    private func subscribeToFriendshipChanges(currentUserId: String) {
        do {
            let query = LCQuery(className: "_Followee")
            
            // 使用 LeanCloud 当前用户 objectId（优先）
            let lcObjectId = LCApplication.default.currentUser?.objectId?.value ?? currentUserId
            if lcObjectId == currentUserId {
            } else {
            }
            // 查询当前用户的好友关系
            query.whereKey("user", .equalTo(LCObject(className: "_User", objectId: lcObjectId)))
            query.whereKey("friendStatus", .equalTo(true))
            
            let liveQuery = try LiveQuery(query: query) { [weak self] liveQuery, event in
                self?.handleFriendshipEvent(event)
            }
            
            liveQuery.subscribe { [weak self] result in
                switch result {
                case .success:
                    self?.friendshipLiveQuery = liveQuery
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.lastError = error
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.lastError = error
            }
        }
    }
    
    /**
     * 处理好友申请事件
     */
    private func handleFriendshipRequestEvent(_ event: LiveQuery.Event) {
        switch event {
        case .create(let object):
            handleNewFriendshipRequest(object)
        case .update(let object, _):
            handleFriendshipRequestUpdate(object)
        case .delete(let object):
            handleFriendshipRequestDelete(object)
        default:
            break
        }
    }
    
    /**
     * 处理好友关系事件
     */
    private func handleFriendshipEvent(_ event: LiveQuery.Event) {
        switch event {
        case .create(let object):
            handleNewFriendship(object)
        case .update(let object, _):
            handleFriendshipUpdate(object)
        case .delete(let object):
            handleFriendshipDelete(object)
        default:
            break
        }
    }
    
    // MARK: - 事件处理
    
    /**
     * 处理新好友申请
     */
    private func handleNewFriendshipRequest(_ object: LCObject) {
        
        // 🎯 修复：从对象中提取发送者ID，然后查询用户名
        var senderId: String? = nil
        var senderName = "未知用户"
        
        // 尝试从 user 字段获取发送者ID
        if let user = object["user"] as? LCObject {
            senderId = user.objectId?.stringValue
        } else if let userPointer = object["user"] as? [String: Any],
                  let userObjectId = userPointer["objectId"] as? String {
            senderId = userObjectId
        }
        
        // 如果有发送者ID，尝试查询用户名
        if let userId = senderId {
            // 从 UserNameRecord 表查询用户名
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, error in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        senderName = name
                    } else {
                    }
                    
                    // 发送通知给UI层
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NewFriendshipRequest"),
                        object: nil,
                        userInfo: ["object": object, "senderName": senderName, "senderId": userId]
                    )
                }
            }
        } else {
            // 发送通知给UI层（即使没有发送者ID）
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewFriendshipRequest"),
                    object: nil,
                    userInfo: ["object": object, "senderName": senderName]
                )
            }
        }
    }
    
    /**
     * 处理好友申请状态变化
     */
    private func handleFriendshipRequestUpdate(_ object: LCObject) {
        
        // 发送通知给UI层
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("FriendshipRequestUpdated"),
                object: nil,
                userInfo: ["object": object]
            )
        }
    }
    
    /**
     * 处理好友申请删除
     */
    private func handleFriendshipRequestDelete(_ object: LCObject) {
        
        // 发送通知给UI层
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("FriendshipRequestDeleted"),
                object: nil,
                userInfo: ["object": object]
            )
        }
    }
    
    /**
     * 处理新好友关系
     */
    private func handleNewFriendship(_ object: LCObject) {
        
        // 发送通知给UI层
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NewFriendship"),
                object: nil,
                userInfo: ["object": object]
            )
        }
    }
    
    /**
     * 处理好友关系更新
     */
    private func handleFriendshipUpdate(_ object: LCObject) {
        
        // 发送通知给UI层
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("FriendshipUpdated"),
                object: nil,
                userInfo: ["object": object]
            )
        }
    }
    
    /**
     * 处理好友关系删除
     */
    private func handleFriendshipDelete(_ object: LCObject) {
        
        // 发送通知给UI层
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("FriendshipDeleted"),
                object: nil,
                userInfo: ["object": object]
            )
        }
    }
}

// MARK: - 通知名称扩展
extension NSNotification.Name {
    static let newFriendshipRequest = NSNotification.Name("NewFriendshipRequest")
    static let friendshipRequestUpdated = NSNotification.Name("FriendshipRequestUpdated")
    static let friendshipRequestDeleted = NSNotification.Name("FriendshipRequestDeleted")
    static let newFriendship = NSNotification.Name("NewFriendship")
    static let friendshipUpdated = NSNotification.Name("FriendshipUpdated")
    static let friendshipDeleted = NSNotification.Name("FriendshipDeleted")
}
