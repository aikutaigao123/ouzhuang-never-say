//
//  LegacySearchView+UserScore.swift
//  NeverSayNo
//
//  Created by Auto on 2025/11/11.
//

import SwiftUI
import Foundation
import CoreLocation
import LeanCloud

// MARK: - 用户积分管理
extension LegacySearchView {
    
    // MARK: - 更新用户积分
    
    /// 更新用户积分（当收到爱心或点赞时）
    func updateUserScore(userId: String, userName: String, userAvatar: String, userEmail: String?, loginType: String, favoriteCount: Int, likeCount: Int) {
        // 先获取用户的位置信息
        getLatestUserLocation(userId: userId) { latitude, longitude in
            let userScore = UserScore(
                userId: userId,
                userName: userName,
                userAvatar: userAvatar,
                userEmail: userEmail,
                loginType: loginType,
                favoriteCount: favoriteCount,
                likeCount: likeCount,
                distance: nil, // 距离现在由排行榜实时计算
                latitude: latitude,
                longitude: longitude
            )
            
            self.uploadUserScoreWithLocation(userScore: userScore)
        }
    }
    
    /// 更新用户积分位置信息
    func updateUserScoreLocation(location: CLLocation, userId: String, userName: String, loginType: String, userEmail: String?, avatar: String, completion: @escaping (Bool) -> Void) {
        // ⚖️ 法律合规：将 WGS-84 坐标转换为 GCJ-02 坐标
        // 根据《中华人民共和国测绘法》要求，UI 显示和数据上传必须使用 GCJ-02 坐标系
        let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        // 🎯 保存LocationRecord的坐标（与上传到LocationRecord表的坐标一致）
        let locationRecordLatitude = gcjLat
        let locationRecordLongitude = gcjLon
        
        
        // 🎯 修改：在更新UserScore前先扣除2钻石，使用扣除后的新钻石数
        diamondManager.spendDiamonds(2) { success in
            guard success else {
                // 扣除钻石失败，不更新UserScore
                completion(false)
                return
            }
            
            // 创建包含位置信息的UserScore对象（使用GCJ-02坐标）
            // 🎯 修改：totalScore 等于扣除后的新钻石数
            let diamonds = diamondManager.diamonds
            let userScore = UserScore(
            userId: userId,
            userName: userName,
            userAvatar: avatar,
            userEmail: userEmail,
            loginType: loginType,
            favoriteCount: 0,
            likeCount: 0,
            distance: nil,
            latitude: gcjLat,
            longitude: gcjLon,
            totalScore: diamonds
        )
        
        
            // 🎯 对比LocationRecord和UserScore的坐标
            let latDiff = abs(locationRecordLatitude - gcjLat)
            let lonDiff = abs(locationRecordLongitude - gcjLon)
            if latDiff < 0.000000001 && lonDiff < 0.000000001 {
            } else {
            }
            
            LeanCloudService.shared.uploadUserScore(
                userScore: userScore,
                locationRecordLatitude: locationRecordLatitude,
                locationRecordLongitude: locationRecordLongitude
            ) { success, error in
                DispatchQueue.main.async {
                    if success {
                    } else {
                    }
                    completion(success)
                }
            }
        }
    }
    
    // MARK: - 获取用户位置和统计信息
    
    /// 获取用户最新的位置信息
    func getLatestUserLocation(userId: String, completion: @escaping (Double?, Double?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "UserScore")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("lastUpdated", .descending)
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first {
                        let latitude = firstRecord["latitude"]?.doubleValue
                        let longitude = firstRecord["longitude"]?.doubleValue
                        completion(latitude, longitude)
                    } else {
                        completion(nil, nil)
                    }
                case .failure(_):
                    completion(nil, nil)
                }
            }
        }
    }
    
    /// 上传包含位置信息的UserScore
    func uploadUserScoreWithLocation(userScore: UserScore) {
        LeanCloudService.shared.uploadUserScore(userScore: userScore) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 积分更新成功
                    // 发送通知，让排行榜刷新数据
                    NotificationCenter.default.post(name: NSNotification.Name("UserScoreUpdated"), object: nil)
                } else {
                    // 积分更新失败
                }
            }
        }
    }
    
    // MARK: - 获取用户统计信息
    
    /// 计算用户收到的爱心数量（从FavoriteRecord表查询）
    func calculateFavoriteCount(for userId: String) -> Int {
        return ReportHelpers.calculateFavoriteCount(for: userId)
    }
    
    /// 异步获取用户收到的爱心数量
    func getFavoriteCount(for userId: String, completion: @escaping (Int) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "FavoriteRecord")
        query.whereKey("favoriteUserId", .equalTo(userId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 0 // 仅用于计数
        
        query.count { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    completion(count)
                case .failure(_):
                    completion(0)
                }
            }
        }
    }
    
    /// 异步获取用户收到的点赞数量
    func getLikeCount(for userId: String, completion: @escaping (Int) -> Void) {
        LeanCloudService.shared.getUserLikeCount(userId: userId) { count, error in
            DispatchQueue.main.async {
                if error.isEmpty {
                    completion(count)
                } else {
                    completion(0)
                }
            }
        }
    }
    
    // MARK: - 打印表内容（调试用）
    
    /// 打印UserScore表内容
    func printUserScoreTableContent() {
        // 获取所有UserScore记录
        let urlString = "\(LeanCloudService.shared.serverUrl)/1.1/classes/UserScore"
        guard let url = URL(string: urlString) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LeanCloudService.shared.appId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(LeanCloudService.shared.appKey, forHTTPHeaderField: "X-LC-Key")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let data = data else {
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        for (_, result) in results.enumerated() {
                            let _ = result["objectId"] as? String ?? "(无)"
                            let _ = result["userId"] as? String ?? "(无)"
                            let _ = result["userName"] as? String ?? "(无)"
                            let _ = result["userAvatar"] as? String ?? "(无)"
                            let _ = result["loginType"] as? String ?? "(无)"
                            let _ = result["favoriteCount"] as? Int ?? 0
                            let _ = result["likeCount"] as? Int ?? 0
                            let _ = result["totalScore"] as? Int ?? 0
                            let _ = result["lastUpdated"] as? String ?? "(无)"
                            let latitude = result["latitude"] as? Double
                            let longitude = result["longitude"] as? Double
                            if let _ = latitude, let _ = longitude {
                            }
                        }
                    }
                } catch {
                }
            }
        }.resume()
    }

    /// 打印UserNameRecord表内容
    func printUserNameRecordTableContent() {
        let urlString = "\(LeanCloudService.shared.serverUrl)/1.1/classes/UserNameRecord"
        guard let url = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LeanCloudService.shared.appId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(LeanCloudService.shared.appKey, forHTTPHeaderField: "X-LC-Key")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                guard let data = data else {
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        for (_, result) in results.enumerated() {
                            let _ = result["objectId"] as? String ?? "(无)"
                            let _ = result["userId"] as? String ?? "(无)"
                            let _ = result["userName"] as? String ?? "(无)"
                            let _ = result["loginType"] as? String ?? "(无)"
                            let _ = result["userEmail"] as? String ?? "(无)"
                            let _ = result["deviceId"] as? String ?? "(无)"
                            let _ = result["deviceTime"] as? String ?? "(无)"
                        }
                    }
                } catch {
                }
            }
        }.resume()
    }
    
    /// 打印LocationRecord表完整内容（分页获取所有数据）
    func printLocationRecordTableContent() {
        var allRecords: [[String: Any]] = []
        let pageSize = 1000
        var skip = 0
        var hasMore = true
        
        func fetchPage() {
            guard hasMore else {
                // 所有数据获取完成，开始打印
                if allRecords.isEmpty {
                } else {
                    for (_, result) in allRecords.enumerated() {
                        let _ = String(repeating: "-", count: 80)
                        
                        // 打印所有字段
                        let _ = result["objectId"] as? String ?? "(无)"
                        let _ = result["userId"] as? String ?? "(无)"
                        let _ = result["userName"] as? String ?? "(无)"
                        let _ = result["loginType"] as? String ?? "(无)"
                        let _ = result["userEmail"] as? String ?? "(无)"
                        let _ = result["userAvatar"] as? String ?? "(无)"
                        let _ = result["deviceId"] as? String ?? "(无)"
                        let _ = result["latitude"] as? Double ?? 0.0
                        let _ = result["longitude"] as? Double ?? 0.0
                        let _ = result["accuracy"] as? Double ?? 0.0
                        let _ = result["deviceTime"] as? String ?? "(无)"
                        let _ = result["timestamp"] as? String ?? "(无)"
                        let _ = result["createdAt"] as? String ?? "(无)"
                        let _ = result["updatedAt"] as? String ?? "(无)"
                        let _ = result["status"] as? String ?? "(无)"
                        let _ = result["recordCount"] as? Int ?? 0
                        let _ = result["likeCount"] as? Int ?? 0
                        let _ = result["clientTimestamp"] as? Double
                        let _ = result["timezone"] as? String ?? "(无)"
                        let _ = result["placeName"] as? String ?? "(无)"
                        let _ = result["reason"] as? String ?? "(无)"
                        
                        // 打印其他可能的字段
                        let knownKeys = Set(["objectId", "userId", "userName", "loginType", "userEmail", "userAvatar", "deviceId", "latitude", "longitude", "accuracy", "deviceTime", "timestamp", "createdAt", "updatedAt", "status", "recordCount", "likeCount", "clientTimestamp", "timezone", "placeName", "reason"])
                        let allKeys = Set(result.keys)
                        let otherKeys = allKeys.subtracting(knownKeys)
                        if !otherKeys.isEmpty {
                            for _ in otherKeys.sorted() {
                            }
                        }
                    }
                }
                return
            }
            
            let urlString = "\(LeanCloudService.shared.serverUrl)/1.1/classes/LocationRecord?order=-createdAt&limit=\(pageSize)&skip=\(skip)"
            guard let url = URL(string: urlString) else {
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(LeanCloudService.shared.appId, forHTTPHeaderField: "X-LC-Id")
            request.setValue(LeanCloudService.shared.appKey, forHTTPHeaderField: "X-LC-Key")
            request.timeoutInterval = 30.0
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if error != nil {
                        hasMore = false
                        fetchPage() // 打印已获取的数据
                        return
                    }
                    
                    guard let data = data else {
                        hasMore = false
                        fetchPage() // 打印已获取的数据
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let results = json["results"] as? [[String: Any]] {
                            allRecords.append(contentsOf: results)
                            
                            if results.count < pageSize {
                                hasMore = false
                            } else {
                                skip += pageSize
                            }
                            
                            fetchPage() // 继续获取下一页或开始打印
                        } else {
                            hasMore = false
                            fetchPage() // 打印已获取的数据
                        }
                    } catch {
                        hasMore = false
                        fetchPage() // 打印已获取的数据
                    }
                }
            }.resume()
        }
        
        fetchPage()
    }
}

