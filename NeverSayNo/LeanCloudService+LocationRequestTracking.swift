//
//  LeanCloudService+LocationRequestTracking.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation

// MARK: - Location Request Tracking Extension
extension LeanCloudService {
    
    // 请求追踪：记录所有对LocationRecord的请求
    static var locationRequestHistory: [(timestamp: Date, operation: String, userId: String?, callStack: String)] = []
    static let requestHistoryQueue = DispatchQueue(label: "com.neverSayNo.locationRequestHistory")
    
    // 请求限流配置
    static let maxRequestsPer10Seconds = 8  // 10秒内最多8个请求（留2个余量）
    static let minSendLocationInterval: TimeInterval = 5.0  // sendLocation最小间隔5秒（优化：从10秒减少到5秒）
    
    /// 获取调用栈信息（简化版，只显示关键函数）
    static func getCallStack() -> String {
        let symbols = Thread.callStackSymbols
        // 只取前5层调用栈，过滤掉系统函数
        let relevantSymbols = symbols.prefix(8).filter { symbol in
            !symbol.contains("libswift") && 
            !symbol.contains("libdispatch") &&
            !symbol.contains("Foundation") &&
            !symbol.contains("CFNetwork")
        }
        return relevantSymbols.joined(separator: " -> ")
    }
    
    /// 记录请求历史
    func recordLocationRequest(operation: String, userId: String?) {
        let callStack = Self.getCallStack()
        Self.requestHistoryQueue.async {
            let now = Date()
            Self.locationRequestHistory.append((timestamp: now, operation: operation, userId: userId, callStack: callStack))
            
            // 只保留最近1分钟内的请求历史
            let oneMinuteAgo = now.addingTimeInterval(-60)
            Self.locationRequestHistory = Self.locationRequestHistory.filter { $0.timestamp > oneMinuteAgo }
            
            // 详细统计不同时间窗口的请求数
            let recent10s = Self.locationRequestHistory.filter { $0.timestamp > now.addingTimeInterval(-10) }
            let recent30s = Self.locationRequestHistory.filter { $0.timestamp > now.addingTimeInterval(-30) }
            // 显示最近请求的详细时间线
            if recent10s.count > 0 {
                let sortedRequests = recent10s.sorted { $0.timestamp < $1.timestamp }
                for (_, req) in sortedRequests.suffix(10).enumerated() {
                    // 如果是sendLocation，显示调用栈
                    if req.operation == "sendLocation" {
                        let stackLines = req.callStack.components(separatedBy: " -> ")
                        if stackLines.count > 0 {
                        }
                    }
                }
                
                // 计算连续请求的最小间隔
                if sortedRequests.count >= 2 {
                    var minInterval: TimeInterval = Double.greatestFiniteMagnitude
                    for i in 1..<sortedRequests.count {
                        let interval = sortedRequests[i].timestamp.timeIntervalSince(sortedRequests[i-1].timestamp)
                        if interval < minInterval {
                            minInterval = interval
                        }
                    }
                }
            }
            
            // 429错误风险评估
            if recent10s.count >= 8 {
            }
            if recent30s.count >= 20 {
            }
        }
    }
}

