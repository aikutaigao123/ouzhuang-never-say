//
//  ContactInquiryLiveQueryManager.swift
//  NeverSayNo
//
//  询问联系方式是否真实LiveQuery实时通知管理器
//  基于LeanCloud LiveQuery实现实时询问通知
//

import Foundation
import LeanCloud
import UIKit

/**
 * 询问联系方式是否真实LiveQuery实时通知管理器
 * 基于LeanCloud LiveQuery实现实时询问通知
 */
class ContactInquiryLiveQueryManager: ObservableObject {
    static let shared = ContactInquiryLiveQueryManager()
    
    // MARK: - 属性
    @Published var isConnected = false
    @Published var lastError: Error?
    
    private var contactInquiryLiveQuery: LiveQuery?  // 监听发给当前用户的询问（status = pending）
    private var contactInquiryReplyLiveQuery: LiveQuery?  // 🎯 新增：监听当前用户发送的询问的回复（status = replied）
    
    private init() {}
    
    // MARK: - 连接管理
    
    /**
     * 启动LiveQuery订阅
     * - Parameter currentUserId: 当前用户ID
     */
    func startSubscription(currentUserId: String) {
        subscribeToContactInquiries(currentUserId: currentUserId)  // 监听发给当前用户的询问
        subscribeToContactInquiryReplies(currentUserId: currentUserId)  // 🎯 新增：监听当前用户发送的询问的回复
    }
    
    /**
     * 停止LiveQuery订阅
     */
    func stopSubscription() {
        contactInquiryLiveQuery?.unsubscribe { _ in }
        contactInquiryLiveQuery = nil
        
        contactInquiryReplyLiveQuery?.unsubscribe { _ in }
        contactInquiryReplyLiveQuery = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    // MARK: - 私有方法
    
    /**
     * 订阅询问通知
     */
    private func subscribeToContactInquiries(currentUserId: String) {
        do {
            let query = LCQuery(className: "ContactInquiry")
            
            // 使用 LeanCloud 当前用户 objectId
            let lcObjectId = LCApplication.default.currentUser?.objectId?.value ?? currentUserId
            
            // 查询发给当前用户的询问（targetUser 指向当前用户，status 为 pending）
            query.whereKey("targetUser", .equalTo(LCObject(className: "_User", objectId: lcObjectId)))
            query.whereKey("status", .equalTo("pending"))
            
            let liveQuery = try LiveQuery(query: query) { [weak self] liveQuery, event in
                self?.handleContactInquiryEvent(event)
            }
            
            liveQuery.subscribe { [weak self] result in
                switch result {
                case .success:
                    self?.contactInquiryLiveQuery = liveQuery
                    
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
     * 订阅询问回复通知（当前用户发送的询问的回复）
     */
    private func subscribeToContactInquiryReplies(currentUserId: String) {
        do {
            let query = LCQuery(className: "ContactInquiry")
            
            // 使用 LeanCloud 当前用户 objectId
            let lcObjectId = LCApplication.default.currentUser?.objectId?.value ?? currentUserId
            
            // 查询当前用户发送的询问的回复（inquirer 指向当前用户，status 为 replied）
            query.whereKey("inquirer", .equalTo(LCObject(className: "_User", objectId: lcObjectId)))
            query.whereKey("status", .equalTo("replied"))
            
            let liveQuery = try LiveQuery(query: query) { [weak self] liveQuery, event in
                self?.handleContactInquiryReplyEvent(event)
            }
            
            liveQuery.subscribe { [weak self] result in
                switch result {
                case .success:
                    self?.contactInquiryReplyLiveQuery = liveQuery
                    
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
     * 处理询问事件
     */
    private func handleContactInquiryEvent(_ event: LiveQuery.Event) {
        switch event {
        case .create(let object):
            handleNewContactInquiry(object)
        case .update(let object, _):
            handleContactInquiryUpdate(object)
        case .delete(let object):
            handleContactInquiryDelete(object)
        default:
            break
        }
    }
    
    // MARK: - 事件处理
    
    /**
     * 处理新询问
     */
    private func handleNewContactInquiry(_ object: LCObject) {
        // 从对象中提取询问者ID，然后查询用户名
        var inquirerId: String? = nil
        var inquirerName = "未知用户"
        
        // 尝试从 inquirer 字段获取询问者ID
        if let inquirer = object["inquirer"] as? LCObject {
            inquirerId = inquirer.objectId?.stringValue
        } else if let inquirerPointer = object["inquirer"] as? [String: Any],
                  let inquirerObjectId = inquirerPointer["objectId"] as? String {
            inquirerId = inquirerObjectId
        }
        
        // 如果有询问者ID，尝试查询用户名
        if let userId = inquirerId {
            // 从 UserNameRecord 表查询用户名
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, error in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        inquirerName = name
                    }
                    
                    // 发送通知给UI层
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NewContactInquiry"),
                        object: nil,
                        userInfo: ["object": object, "senderName": inquirerName, "senderId": userId]
                    )
                }
            }
        } else {
            // 发送通知给UI层（即使没有询问者ID）
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewContactInquiry"),
                    object: nil,
                    userInfo: ["object": object, "senderName": inquirerName]
                )
            }
        }
    }
    
    /**
     * 处理询问状态变化（当发给当前用户的询问状态变化时）
     */
    private func handleContactInquiryUpdate(_ object: LCObject) {
        // 可以在这里处理其他状态变化
    }
    
    /**
     * 处理询问回复事件
     */
    private func handleContactInquiryReplyEvent(_ event: LiveQuery.Event) {
        switch event {
        case .create(let object):
            // 新创建的 replied 记录（通常不会发生，因为是从 pending 更新而来）
            handleContactInquiryReply(object)
        case .update(let object, _):
            // status 从 pending 变为 replied
            handleContactInquiryReply(object)
        default:
            break
        }
    }
    
    /**
     * 处理询问回复（当前用户发送的询问被回复）
     */
    private func handleContactInquiryReply(_ object: LCObject) {
        // 从对象中提取回复者ID（targetUser），然后查询用户名
        var replierId: String? = nil
        var replierName = "未知用户"
        
        // 尝试从 targetUser 字段获取回复者ID（回复者是 targetUser）
        if let targetUser = object["targetUser"] as? LCObject {
            replierId = targetUser.objectId?.stringValue
        } else if let targetUserPointer = object["targetUser"] as? [String: Any],
                  let targetUserObjectId = targetUserPointer["objectId"] as? String {
            replierId = targetUserObjectId
        }
        
        // 如果有回复者ID，尝试查询用户名
        if let userId = replierId {
            // 从 UserNameRecord 表查询用户名
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, error in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        replierName = name
                    }
                    
                    // 发送通知给UI层
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NewContactInquiryReply"),
                        object: nil,
                        userInfo: ["object": object, "senderName": replierName, "senderId": userId]
                    )
                }
            }
        } else {
            // 发送通知给UI层（即使没有回复者ID）
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewContactInquiryReply"),
                    object: nil,
                    userInfo: ["object": object, "senderName": replierName]
                )
            }
        }
    }
    
    /**
     * 处理询问删除
     */
    private func handleContactInquiryDelete(_ object: LCObject) {
        // 可以在这里处理询问删除
    }
}
