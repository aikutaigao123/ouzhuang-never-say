//
//  LeanCloudService+LocationSend.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import UIKit

// MARK: - Location Send Extension
extension LeanCloudService {
    
    /// 发送位置信息（带限流保护）
    func sendLocation(locationData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        sendLocation(locationData: locationData, retryCount: 0, completion: completion)
    }
    
    /// 发送位置信息（内部实现，支持重试）
    func sendLocation(locationData: [String: Any], retryCount: Int, completion: @escaping (Bool, String) -> Void) {
        let userId = locationData["userId"] as? String ?? "unknown"
        
        // 🎯 新增：防重复上传检查
        // 注意：如果是重试（retryCount > 0），允许通过，因为这是同一个上传流程的重试
        uploadingLocationLock.lock()
        let currentUploadingState = isUploadingLocation
        uploadingLocationLock.unlock()
        
        
        // 如果是重试（retryCount > 0），允许通过
        if currentUploadingState && retryCount == 0 {
            completion(false, "正在上传中，跳过重复调用")
            return
        }
        
        // 只有在非重试时才设置 isUploadingLocation = true
        if retryCount == 0 {
            uploadingLocationLock.lock()
            isUploadingLocation = true
            uploadingLocationLock.unlock()
        } else {
        }
        
        
        // 验证API配置
        guard validateAPIConfig() else {
            if retryCount == 0 {
                uploadingLocationLock.lock()
                isUploadingLocation = false
                uploadingLocationLock.unlock()
            }
            completion(false, "API配置无效")
            return
        }
        
        let requestStartTime = Date()
        
        // 限流检查（优化：更准确地预测429错误）
        let shouldThrottle = Self.requestHistoryQueue.sync { () -> (Bool, TimeInterval?) in
            // 检查多个时间窗口的请求数（LeanCloud可能使用不同的时间窗口）
            let recent3s = Self.locationRequestHistory.filter { $0.timestamp > requestStartTime.addingTimeInterval(-3) }
            let recent5s = Self.locationRequestHistory.filter { $0.timestamp > requestStartTime.addingTimeInterval(-5) }
            
            // 如果最近5秒内请求数 >= 5，说明请求很密集，需要更长的等待时间
            if recent5s.count >= 5 {
            }
            
            // 如果最近3秒内请求数 >= 4，可能触发LeanCloud的短时间窗口限流
            if recent3s.count >= 4 {
            }
            
            // 检查sendLocation的最小间隔（已取消"10秒内最多1个"的限制，只检查1/17秒间隔）
            let allSendLocationRequests = Self.locationRequestHistory.filter { $0.operation == "sendLocation" }
            
            // 只检查距离上次sendLocation是否至少1/17秒
            if let lastSendLocation = allSendLocationRequests.last {
                let timeSinceLast = requestStartTime.timeIntervalSince(lastSendLocation.timestamp)
                
                // 如果距离上次sendLocation小于1/17秒，延迟1/17秒
                if timeSinceLast < 1.0/17.0 {
                    let waitTime = 1.0/17.0 - timeSinceLast
                    return (true, waitTime)
                } else {
                }
            } else {
            }
            
            return (false, nil)
        }
        
        // 如果需要限流
        if shouldThrottle.0 {
            if let waitTime = shouldThrottle.1 {
                // 延迟发送
                DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
                    // 延迟后再次检查请求历史，确保安全
                    let delayedCheckTime = Date()
                    _ = Self.requestHistoryQueue.sync {
                        Self.locationRequestHistory.filter { $0.timestamp > delayedCheckTime.addingTimeInterval(-5) }
                    }
                    let delayedRecent3s = Self.requestHistoryQueue.sync {
                        Self.locationRequestHistory.filter { $0.timestamp > delayedCheckTime.addingTimeInterval(-3) }
                    }
                    
                    if delayedRecent3s.count >= 4 {
                    }
                    
                    self.sendLocation(locationData: locationData, completion: completion)
                }
                return
            } else {
                // 直接拒绝
                completion(false, "请求过于频繁，请稍后再试")
                return
            }
        }
        
        // 构建请求URL
        let url = URL(string: "\(serverUrl)/1.1/classes/LocationRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(appKey, forHTTPHeaderField: "X-LC-Key")
        
        // 设置请求体
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: locationData)
        } catch {
            completion(false, "JSON序列化失败: \(error.localizedDescription)")
            return
        }
        
        // 记录请求历史
        recordLocationRequest(operation: "sendLocation", userId: userId)
        
        // 计算距离上次请求的时间间隔，并检查是否有重复调用
        Self.requestHistoryQueue.sync {
            let allSendLocationRequests = Self.locationRequestHistory.filter { $0.operation == "sendLocation" }
            let recentSendLocationRequests = allSendLocationRequests.filter { $0.timestamp > requestStartTime.addingTimeInterval(-10) }
            
            if let lastRequest = Self.locationRequestHistory.dropLast().last {
                let timeSinceLastRequest = requestStartTime.timeIntervalSince(lastRequest.timestamp)
                
                // 检查是否有重复的sendLocation调用
                if lastRequest.operation == "sendLocation" && timeSinceLastRequest < 1.0 {
                }
            } else {
            }
            
            // 统计最近10秒内的sendLocation请求
            if recentSendLocationRequests.count >= 2 {
                
                // 分析sendLocation请求的时间分布
                let sortedSendLocation = recentSendLocationRequests.sorted { $0.timestamp < $1.timestamp }
                for (_, _) in sortedSendLocation.enumerated() {
                }
                
                // 计算sendLocation请求的最小间隔
                if sortedSendLocation.count >= 2 {
                    var minInterval: TimeInterval = Double.greatestFiniteMagnitude
                    for i in 1..<sortedSendLocation.count {
                        let interval = sortedSendLocation[i].timestamp.timeIntervalSince(sortedSendLocation[i-1].timestamp)
                        if interval < minInterval {
                            minInterval = interval
                        }
                    }
                }
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            DispatchQueue.main.async {
                
                if let error = error {
                    // 🎯 网络错误后，重置上传状态
                    if retryCount == 0 {
                        self.uploadingLocationLock.lock()
                        self.isUploadingLocation = false
                        self.uploadingLocationLock.unlock()
                    }
                    self.handleNetworkError(error, request, operation: "发送位置")
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "无效的HTTP响应")
                    return
                }
                
                
                
                if data != nil {
                }
                
                if httpResponse.statusCode == 201 {
                    if let responseData = data {
                        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                           json["objectId"] as? String != nil {
                        }
                    }
                    // 🎯 上传成功后，重置上传状态
                    if retryCount == 0 {
                        self.uploadingLocationLock.lock()
                        self.isUploadingLocation = false
                        self.uploadingLocationLock.unlock()
                    }
                    completion(true, "位置发送成功")
                } else if httpResponse.statusCode == 429 {
                    // 429错误，静默重试
                    let maxRetries = 17
                    if retryCount < maxRetries {
                        let retryDelay: TimeInterval = 1.0/17.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                            self.sendLocation(locationData: locationData, retryCount: retryCount + 1, completion: completion)
                        }
                        return
                    } else {
                        // 🎯 重试失败后，重置上传状态
                        if retryCount == 0 {
                            self.uploadingLocationLock.lock()
                            self.isUploadingLocation = false
                            self.uploadingLocationLock.unlock()
                        }
                        completion(false, "请求频率过高，请稍后再试")
                    }
                } else {
                    // 🎯 上传失败后，重置上传状态
                    if retryCount == 0 {
                        self.uploadingLocationLock.lock()
                        self.isUploadingLocation = false
                        self.uploadingLocationLock.unlock()
                    }
                    self.handle403ForbiddenError(request, httpResponse, data ?? Data(), operation: "发送位置")
                    completion(false, "服务器错误: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}

