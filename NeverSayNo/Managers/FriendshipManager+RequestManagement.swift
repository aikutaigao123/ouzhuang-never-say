import Foundation
import LeanCloud

extension FriendshipManager {
    // MARK: - 好友申请管理
    
    /**
     * 发送好友申请（符合 LeanCloud 好友关系开发指南）
     * 
     * 根据开发指南：
     * - 成功后，_FriendshipRequest 表新增一条数据，status 为 "pending"
     * - 如果提供了 attributes，_Followee 表也会增加一条数据：
     *   - user 列为当前用户，followee 列为目标用户
     *   - friendStatus 为 false（表示对方尚未接受）
     *   - attributes 会被存储到相应的列中
     * 
     * - Parameters:
     *   - targetUserId: 目标用户ID（LeanCloud _User 表的 objectId）
     *   - attributes: 可选的好友属性（会在 _Followee 表中存储为自定义列）
     *   - completion: 完成回调
     */
    func sendFriendshipRequest(
        to targetUserId: String,
        attributes: [String: Any]? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        
        isLoading = true
        lastError = nil
        
        // 获取当前用户的 LeanCloud objectId
        guard let currentUser = LCApplication.default.currentUser else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
                completion(false, "用户未登录")
            }
            return
        }
        
        let currentUserObjectId = currentUser.objectId?.value ?? ""
        
        if currentUserObjectId.isEmpty {
            DispatchQueue.main.async {
                self.isLoading = false
                self.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户objectId为空"])
                completion(false, "用户objectId为空")
            }
            return
        }
        
        // 🎯 新增：先检查是否存在被拒绝的申请
        let whereCondition: [String: Any] = [
            "user": [
                "__type": "Pointer",
                "className": "_User",
                "objectId": currentUserObjectId
            ],
            "friend": [
                "__type": "Pointer",
                "className": "_User",
                "objectId": targetUserId
            ],
            "status": "declined"
        ]
        
        queryFriendshipRequestsAPI(whereCondition: whereCondition) { [weak self] declinedRequests, error in
            if error != nil {
                // 即使查询出错，也尝试继续发送（可能是网络问题）
                self?.sendFriendshipRequestAfterCheck(to: targetUserId, attributes: attributes, completion: completion)
                return
            }
            
            if let declinedRequests = declinedRequests, !declinedRequests.isEmpty {
                
                // 🎯 尝试删除被拒绝的申请，然后重新发送
                if let firstDeclinedRequest = declinedRequests.first {
                    self?.deleteFriendshipRequest(requestId: firstDeclinedRequest.objectId) { deleteSuccess, deleteError in
                        if deleteSuccess {
                            // 延迟一下再发送，确保删除操作完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self?.sendFriendshipRequestAfterCheck(to: targetUserId, attributes: attributes, completion: completion)
                            }
                        } else {
                            DispatchQueue.main.async {
                                self?.isLoading = false
                                let errorMsg = "无法发送好友申请：之前的好友申请已被拒绝，且无法删除。请等待对方主动添加您为好友。"
                                self?.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                                completion(false, errorMsg)
                            }
                        }
                    }
                } else {
                    // 如果没有找到被拒绝的申请，继续正常发送流程
                    self?.sendFriendshipRequestAfterCheck(to: targetUserId, attributes: attributes, completion: completion)
                }
            } else {
                // 没有发现被拒绝的申请，继续正常发送流程
                self?.sendFriendshipRequestAfterCheck(to: targetUserId, attributes: attributes, completion: completion)
            }
        }
    }
    
    /// 发送好友申请（内部方法，在检查被拒绝申请后调用）
    private func sendFriendshipRequestAfterCheck(
        to targetUserId: String,
        attributes: [String: Any]? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        
        // 获取当前用户的 LeanCloud objectId
        guard let currentUser = LCApplication.default.currentUser else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
                completion(false, "用户未登录")
            }
            return
        }
        
        let currentUserObjectId = currentUser.objectId?.value ?? ""
        
        // 🎯 符合开发指南：构建请求数据
        // user: 发起申请的用户（当前用户）
        // friend: 目标好友用户
        // friendship: 可选的好友属性（会存储到 _Followee 表）
        var requestData: [String: Any] = [
            "user": [
                "__type": "Pointer",
                "className": "_User",
                "objectId": currentUserObjectId
            ],
            "friend": [
                "__type": "Pointer",
                "className": "_User",
                "objectId": targetUserId
            ]
        ]
        
        // 🎯 符合开发指南：如果提供了 attributes，会在 _Followee 表中创建记录
        if let attributes = attributes {
            requestData["friendship"] = attributes
        }
        
        
        // 发送REST API请求
        sendFriendshipRequestAPI(requestData: requestData) { [weak self] success, errorMessage in
            if errorMessage != nil {
            }
            
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    self?.lastError = nil
                    completion(true, "好友申请发送成功")
                } else {
                    var finalErrorMessage = errorMessage ?? "发送失败"
                    // 🎯 新增：如果错误是被拒绝，提供更友好的提示
                    if let errorMsg = errorMessage, errorMsg.contains("previously been declined") {
                        finalErrorMessage = "无法发送好友申请：之前的好友申请已被拒绝。请等待对方主动添加您为好友。"
                    }
                    self?.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: finalErrorMessage])
                    completion(false, finalErrorMessage)
                }
            }
        }
    }
    
    /**
     * 查询好友申请（符合 LeanCloud 好友关系开发指南）
     * 
     * 根据开发指南：
     * - 查询 _FriendshipRequest 表
     * - 查询方式与普通表查询相同，支持 where、order、skip、limit、count、include 等
     * - status 字段：pending（待处理）、accepted（已接受）、declined（已拒绝）
     * - 包括当前用户发送的申请和接收到的申请
     * 
     * - Parameters:
     *   - status: 查询状态 (pending/accepted/declined)，nil表示查询所有状态
     *   - completion: 完成回调
     */
    func fetchFriendshipRequests(status: String? = nil, completion: @escaping ([FriendshipRequest]?, Error?) -> Void) {
        isLoading = true
        lastError = nil
        
        
        // 获取当前用户的 LeanCloud objectId
        guard let currentUser = LCApplication.default.currentUser else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
                completion(nil, self.lastError)
            }
            return
        }
        
        let currentUserObjectId = currentUser.objectId?.value ?? ""
        
        // 🎯 修改：使用 $or 查询，包括：
        // 1. friend 指向当前用户（别人向当前用户发送的申请）
        // 2. user 指向当前用户（当前用户发送的申请）
        var whereCondition: [String: Any] = [
            "$or": [
                [
                    "friend": [
                        "__type": "Pointer",
                        "className": "_User",
                        "objectId": currentUserObjectId
                    ]
                ],
                [
                    "user": [
                        "__type": "Pointer",
                        "className": "_User",
                        "objectId": currentUserObjectId
                    ]
                ]
            ]
        ]
        
        // 如果指定了状态，添加状态过滤条件
        if let status = status {
            whereCondition["status"] = status
        }
        
        // 发送REST API请求
        queryFriendshipRequestsAPI(whereCondition: whereCondition) { [weak self] requests, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.lastError = error
                    completion(nil, error)
                } else {
                    if let requests = requests {
                        for _ in requests {
                        }
                    }
                    self?.friendshipRequests = requests ?? []
                    self?.lastError = nil
                    completion(requests, nil)
                }
            }
        }
    }

    /// 带限流退避重试的好友申请查询
    /// - Parameters:
    ///   - status: 查询状态 (pending/accepted/declined)，nil表示查询所有
    ///   - maxAttempts: 最大重试次数（包含首次请求）
    ///   - completion: 完成回调
    func fetchFriendshipRequestsWithRetry(status: String? = nil, maxAttempts: Int = 3, completion: @escaping ([FriendshipRequest]?, Error?) -> Void) {
        
        let delays: [TimeInterval] = [0.0, 0.6, 1.2, 2.4] // 指数退避，首个为立即
        func attempt(_ index: Int) {
            fetchFriendshipRequests(status: status) { [weak self] requests, error in
                if let nsErr = error as NSError?, nsErr.code == 429, index + 1 < min(maxAttempts, delays.count) {
                    let delay = delays[index + 1]
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        attempt(index + 1)
                    }
                    return
                }
                // 成功或非429错误，结束
                if requests != nil {
                    // 更新缓存已在内部完成，这里仅回调
                    completion(requests, nil)
                } else {
                    self?.lastError = error
                    completion(nil, error)
                }
            }
        }
        attempt(0)
    }
    
    /**
     * 接受好友申请（符合 LeanCloud 好友关系开发指南）
     * 
     * 根据开发指南，接受好友申请后：
     * - _FriendshipRequest 表中该条申请的 status 会被更新为 "accepted"
     * - _Followee 表中已有的记录（user 为 A，followee 为 B）：
     *   - friendStatus 会被更新为 true（表示 B 是 A 的好友）
     *   - 如果有 attributes，会更新相应的属性列
     * - _Followee 表中新增一条记录（user 为 B，followee 为 A）：
     *   - friendStatus 为 true（表示 A 是 B 的好友）
     *   - 如果有 attributes，会设置相应的属性列
     * 
     * - Parameters:
     *   - request: 好友申请对象（从 _FriendshipRequest 表查询得到）
     *   - attributes: 可选的好友属性（会存储到 _Followee 表的相应列中）
     *   - completion: 完成回调
     */
    func acceptFriendshipRequest(
        _ request: FriendshipRequest,
        attributes: [String: Any]? = nil,
        completion: @escaping (Bool, String?) -> Void
    ) {
        isLoading = true
        lastError = nil
        
        // 🎯 符合开发指南：构建请求数据
        // friendship: 可选的好友属性，会被存储到 _Followee 表的相应列中
        var requestData: [String: Any] = [:]
        if let attributes = attributes {
            requestData["friendship"] = attributes
        }
        
        // 🎯 符合开发指南：使用 REST API 接受好友申请
        // PUT /users/friendshipRequests/<request-object-id>/accept
        acceptFriendshipRequestAPI(requestId: request.objectId, requestData: requestData) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    self?.lastError = nil
                    // 刷新好友申请列表
                    self?.fetchFriendshipRequests { requests, _ in
                        DispatchQueue.main.async {
                            if let requests = requests {
                                for _ in requests {
                                }
                            }
                            completion(true, "好友申请已接受")
                        }
                    }
                } else {
                    self?.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "接受失败"])
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    /**
     * 拒绝好友申请（符合 LeanCloud 好友关系开发指南）
     * 
     * 根据开发指南，拒绝好友申请后：
     * - _FriendshipRequest 表中该条申请的 status 会被更新为 "declined"
     * - 注意：用户 A 拒绝 B 的申请后，B 无法再次发起好友申请
     * - 如果两人重新希望成为好友，需要找到之前被拒绝的申请，改为接受
     * 
     * - Parameters:
     *   - request: 好友申请对象（从 _FriendshipRequest 表查询得到）
     *   - completion: 完成回调
     */
    func declineFriendshipRequest(
        _ request: FriendshipRequest,
        completion: @escaping (Bool, String?) -> Void
    ) {
        isLoading = true
        lastError = nil
        
        // 🎯 符合开发指南：使用 REST API 拒绝好友申请
        // PUT /users/friendshipRequests/<request-object-id>/decline
        declineFriendshipRequestAPI(requestId: request.objectId) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    self?.lastError = nil
                    // 刷新好友申请列表
                    self?.fetchFriendshipRequests { requests, _ in
                        DispatchQueue.main.async {
                            if let requests = requests {
                                for _ in requests {
                                }
                            }
                            completion(true, "好友申请已拒绝")
                        }
                    }
                } else {
                    self?.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "拒绝失败"])
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    /**
     * 删除好友申请（符合 LeanCloud 好友关系开发指南）
     * 
     * 根据开发指南：
     * - 删除 _FriendshipRequest 表中的申请记录
     * - 使用 DELETE /classes/_FriendshipRequest/<objectId>
     * - 删除成功后返回空对象 {}
     * 
     * - Parameters:
     *   - requestId: 好友申请的 objectId（_FriendshipRequest 表的 objectId）
     *   - completion: 完成回调
     */
    func deleteFriendshipRequest(
        requestId: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        
        isLoading = true
        lastError = nil
        
        // 🎯 符合开发指南：使用 REST API 删除好友申请
        // DELETE /classes/_FriendshipRequest/<objectId>
        deleteFriendshipRequestAPI(requestId: requestId) { [weak self] success, errorMessage in
            if errorMessage != nil {
            }
            
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    self?.lastError = nil
                    // 刷新好友申请列表
                    self?.fetchFriendshipRequests { _, _ in }
                    completion(true, "好友申请已删除")
                } else {
                    self?.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "删除失败"])
                    completion(false, errorMessage)
                }
            }
        }
    }
}

