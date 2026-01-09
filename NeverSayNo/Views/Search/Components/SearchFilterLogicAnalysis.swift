//
//  SearchFilterLogicAnalysis.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  寻找按钮过滤逻辑分析
//

import Foundation
import CoreLocation

/**
 * 寻找按钮过滤逻辑分析
 * 详细说明所有过滤条件和优先级
 */
struct SearchFilterLogicAnalysis {
    
    // MARK: - 过滤逻辑层次结构
    
    /**
     * 寻找按钮的完整过滤逻辑
     * 按照优先级从高到低排列
     */
    static func analyzeFilterLogic() -> FilterLogicReport {
        
        let report = FilterLogicReport()
        
        // 第一层：基础状态过滤
        report.addFilter(
            level: 1,
            name: "基础状态过滤",
            description: "检查按钮是否可以被点击",
            conditions: [
                "加载状态检查 (isLoading)",
                "黑名单状态检查 (isUserBlacklisted)",
                "位置权限检查 (locationManager.location != nil)"
            ],
            priority: "最高",
            impact: "按钮禁用"
        )
        
        // 第二层：钻石余额过滤
        report.addFilter(
            level: 2,
            name: "钻石余额过滤",
            description: "检查用户是否有足够的钻石进行搜索",
            conditions: [
                "钻石余额检查 (diamondManager.hasEnoughDiamonds(2))",
                "服务器连接状态检查 (isServerConnected)"
            ],
            priority: "高",
            impact: "跳转充值页面或执行搜索"
        )
        
        // 第三层：用户身份过滤
        report.addFilter(
            level: 3,
            name: "用户身份过滤",
            description: "排除当前用户自己",
            conditions: [
                "当前用户ID检查 (location.userId != currentUserId)"
            ],
            priority: "高",
            impact: "排除自己"
        )
        
        // 第四层：历史记录过滤
        report.addFilter(
            level: 4,
            name: "历史记录过滤",
            description: "排除已经匹配过的用户",
            conditions: [
                "历史记录检查 (excludeHistory.contains(location.userId))",
                "历史记录数量限制 (最多217条)"
            ],
            priority: "高",
            impact: "避免重复匹配"
        )
        
        // 第五层：用户类型过滤
        report.addFilter(
            level: 5,
            name: "用户类型过滤",
            description: "排除特定类型的用户",
            conditions: [
                "游客用户过滤 (location.loginType != \"guest\")",
                "用户类型验证 (只匹配 Apple ID 用户和内部用户)"
            ],
            priority: "中",
            impact: "只匹配正式用户"
        )
        
        // 第六层：黑名单过滤
        report.addFilter(
            level: 6,
            name: "黑名单过滤",
            description: "排除黑名单用户和待删除用户",
            conditions: [
                "黑名单用户检查 (blacklistedUserIds.contains(location.userId))",
                "黑名单设备检查 (blacklistedDeviceIds.contains(location.deviceId))",
                "待删除用户检查 (pendingDeletionUserIds.contains(location.userId / userName / deviceId))"
            ],
            priority: "中",
            impact: "排除不良用户"
        )
        
        // 第七层：距离过滤（可选）
        report.addFilter(
            level: 7,
            name: "距离过滤",
            description: "排除距离过近的用户",
            conditions: [
                "距离计算 (calculateDistance)",
                "最小距离限制 (距离 > 10米)"
            ],
            priority: "低",
            impact: "避免匹配过近用户",
            isOptional: true
        )
        
        // 第八层：时间过滤（可选）
        report.addFilter(
            level: 8,
            name: "时间过滤",
            description: "排除时间过旧的记录",
            conditions: [
                "时间戳检查 (isRecentLocation)",
                "时间有效性验证"
            ],
            priority: "低",
            impact: "只匹配活跃用户",
            isOptional: true
        )
        
        // 第九层：随机选择
        report.addFilter(
            level: 9,
            name: "随机选择",
            description: "从符合条件的用户中随机选择一个",
            conditions: [
                "随机索引生成 (Int.random(in: 0..<filteredLocations.count))",
                "最终用户选择"
            ],
            priority: "最低",
            impact: "确定最终匹配结果"
        )
        
        return report
    }
}

// MARK: - 过滤逻辑报告

class FilterLogicReport {
    private var filters: [FilterInfo] = []
    
    func addFilter(level: Int, name: String, description: String, conditions: [String], priority: String, impact: String, isOptional: Bool = false) {
        let filter = FilterInfo(
            level: level,
            name: name,
            description: description,
            conditions: conditions,
            priority: priority,
            impact: impact,
            isOptional: isOptional
        )
        filters.append(filter)
    }
    
    func generateReport() -> String {
        var report = "🔍 寻找按钮过滤逻辑分析报告\n"
        report += String(repeating: "=", count: 60) + "\n"
        
        for filter in filters.sorted(by: { $0.level < $1.level }) {
            report += "\n📋 第\(filter.level)层: \(filter.name)\n"
            report += "📝 描述: \(filter.description)\n"
            report += "⚡ 优先级: \(filter.priority)\n"
            report += "🎯 影响: \(filter.impact)\n"
            if filter.isOptional {
                report += "🔧 状态: 可选\n"
            }
            report += "📊 条件:\n"
            for condition in filter.conditions {
                report += "   • \(condition)\n"
            }
            report += String(repeating: "-", count: 40) + "\n"
        }
        
        report += "\n📈 过滤逻辑总结:\n"
        report += "• 总共 \(filters.count) 层过滤逻辑\n"
        report += "• 必选过滤: \(filters.filter { !$0.isOptional }.count) 层\n"
        report += "• 可选过滤: \(filters.filter { $0.isOptional }.count) 层\n"
        report += "• 最终结果: 从所有符合条件的用户中随机选择一个\n"
        
        return report
    }
}

// MARK: - 过滤信息结构体

struct FilterInfo {
    let level: Int
    let name: String
    let description: String
    let conditions: [String]
    let priority: String
    let impact: String
    let isOptional: Bool
}

