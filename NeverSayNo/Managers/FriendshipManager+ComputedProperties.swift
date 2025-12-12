import Foundation

extension FriendshipManager {
    // MARK: - 扩展方法
    
    /**
     * 获取好友申请数量
     * - Returns: 好友申请数量
     */
    var friendshipRequestCount: Int {
        return friendshipRequests.filter { $0.status == "pending" }.count
    }
    
    /**
     * 获取好友数量
     * - Returns: 好友数量
     */
    var friendsCount: Int {
        return friends.count
    }
}



