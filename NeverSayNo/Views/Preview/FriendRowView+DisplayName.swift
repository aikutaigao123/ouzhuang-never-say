//
//  FriendRowView+DisplayName.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import SwiftUI

extension FriendRowView {
    // 获取显示的用户名（优先使用实时查询结果）
    var displayedName: String {
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        let defaultName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
        
        // 第一优先级：实时查询的结果（来自 UserNameRecord 表）
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        
        // 第二优先级：friendInfo中的用户名（可能来自本地缓存或MatchRecord默认值）
        let infoName = friendInfo.name
        if let cachedName = userNameCache[friendId], !cachedName.isEmpty, cachedName == infoName {
        } else if infoName == defaultName {
        } else {
        }
        return infoName
    }
}

