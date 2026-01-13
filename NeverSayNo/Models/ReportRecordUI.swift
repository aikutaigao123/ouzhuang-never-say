//
//  ReportRecordUI.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import Foundation

struct ReportRecordUI {
    let id: String
    let reporterName: String
    let reportedName: String
    let reportedUserId: String // 🎯 新增：被举报用户的ID
    let reportedUserLoginType: String? // 被举报用户的用户类型
    let reportedUserAvatar: String?     // 被举报用户真实头像
    let reason: String
    let description: String
    var status: String
    let createdAt: Date
}

// 举报操作类型
enum ReportAction {
    case reject
    case warn
    case ban
}
