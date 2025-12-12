//
//  FriendRowView+TimeFormatting.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import SwiftUI

extension FriendRowView {
    // 格式化最近活跃时间 - 全部使用本地时间计算
    func formatLastActiveTime(_ date: Date) -> String {
        // 获取当前本地时间
        let now = Date()
        
        // 计算本地时间差
        let timeInterval = now.timeIntervalSince(date)
        
        // 添加本地时间调试信息
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        
        
        
        let result: String
        if timeInterval < 60 {
            result = "刚刚"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            result = "\(minutes)分钟前"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            result = "\(hours)小时前"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            result = "\(days)天前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd"
            formatter.timeZone = TimeZone.current
            result = formatter.string(from: date)
        }
        
        return result
    }
}

