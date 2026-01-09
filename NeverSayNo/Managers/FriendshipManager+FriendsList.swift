import Foundation
import LeanCloud

extension FriendshipManager {
    // MARK: - 好友列表管理
    
    /**
     * 查询好友列表（符合 LeanCloud 好友关系开发指南）
     * 
     * 根据开发指南：
     * - 查询 _Followee 表，设定 friendStatus=true 查询双向好友
     * - 返回的是互相关注的好友列表
     * - 支持 skip、limit、include 等标准查询参数
     * 
     * - Parameter completion: 完成回调
     */
    func fetchFriendsList(completion: @escaping ([UserInfo]?, Error?) -> Void) {
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
        
        // 🎯 符合开发指南：查询 _Followee 表，friendStatus=true 表示双向好友
        // 查询条件：user 为当前用户，friendStatus 为 true
        let whereCondition: [String: Any] = [
            "user": [
                "__type": "Pointer",
                "className": "_User",
                "objectId": currentUserObjectId
            ],
            "friendStatus": true
        ]
        
        // 发送REST API请求
        queryFriendsListAPI(whereCondition: whereCondition) { [weak self] friends, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.lastError = error
                    completion(nil, error)
                } else {
                    self?.friends = friends ?? []
                    self?.lastError = nil
                    completion(friends, nil)
                }
            }
        }
    }
    
    /**
     * 修改好友属性（符合 LeanCloud 好友关系开发指南）
     * 
     * 根据开发指南：
     * - 在申请好友的过程中，可以随时修改好友属性
     * - 属性字段可以任意指定自己需要的 key 和 value
     * - 使用 PUT /users/<user_id>/friendship/<friend_id>
     * - 属性会被存储到 _Followee 表的相应列中
     * 
     * - Parameters:
     *   - friendUserId: 好友用户ID（LeanCloud _User 表的 objectId）
     *   - attributes: 好友属性字典，每个 key 会成为 _Followee 表的新列
     *   - completion: 完成回调
     */
    func updateFriendAttributes(
        _ friendUserId: String,
        attributes: [String: Any],
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
        
        // 🎯 符合开发指南：使用 REST API 修改好友属性
        // PUT /users/<user_id>/friendship/<friend_id>
        updateFriendAttributesAPI(userId: currentUserObjectId, friendId: friendUserId, attributes: attributes) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    self?.lastError = nil
                    // 刷新好友列表
                    self?.fetchFriendsList { _, _ in }
                    completion(true, "好友属性已更新")
                } else {
                    self?.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "更新失败"])
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    /**
     * 删除好友（符合 LeanCloud 好友关系开发指南）
     * 
     * 根据开发指南：
     * - 删除好友只会删掉 _Followee 表中当前用户的好友数据
     * - 对方的好友数据依然保留
     * - 也就是说当前用户不再视对方为好友，但在对方的好友列表中依然有当前用户
     * - 使用 DELETE /users/<user_id>/friendship/<target_id>
     * 
     * - Parameters:
     *   - friendUserId: 好友用户ID（LeanCloud _User 表的 objectId）
     *   - completion: 完成回调
     */
    func removeFriend(
        _ friendUserId: String,
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
        
        // 🎯 符合开发指南：使用 REST API 删除好友
        // DELETE /users/<user_id>/friendship/<target_id>
        // 只会删除当前用户的 _Followee 记录，对方的记录保留
        removeFriendAPI(userId: currentUserObjectId, friendId: friendUserId) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    self?.lastError = nil
                    // 刷新好友列表
                    self?.fetchFriendsList { _, _ in }
                    completion(true, "好友已删除")
                } else {
                    self?.lastError = NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "删除失败"])
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    // MARK: - 工具方法
    
    /**
     * 检查是否为好友
     * - Parameter userId: 用户ID
     * - Returns: 是否为好友
     */
    func isFriend(_ userId: String) -> Bool {
        return friends.contains { $0.id == userId }
    }
    
    /**
     * 检查是否有待处理的好友申请
     * - Parameter userId: 用户ID
     * - Returns: 是否有待处理的申请
     */
    func hasPendingRequest(from userId: String) -> Bool {
        return friendshipRequests.contains { request in
            request.user.id == userId && request.status == "pending"
        }
    }
}



