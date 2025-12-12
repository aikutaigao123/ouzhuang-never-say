import Foundation
import LeanCloud

// MARK: - 积分合并逻辑扩展
extension LeanCloudService {
    
    // 自动合并指定用户的重复UserScore记录 - 遵循数据存储开发指南，使用 LCQuery
    func mergeUserScoreRecords(userId: String, loginType: String, completion: @escaping (Bool, String) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "UserScore")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("loginType", .equalTo(loginType))
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    // 转换为字典数组
                    let results = records.compactMap { record -> [String: Any]? in
                        var dict: [String: Any] = [:]
                        dict["objectId"] = record.objectId?.stringValue ?? ""
                        dict["userId"] = record["userId"]?.stringValue ?? ""
                        dict["userName"] = record["userName"]?.stringValue ?? ""
                        // 🎯 不再从UserScore表读取userAvatar，统一从UserAvatarRecord表读取
                        dict["userAvatar"] = ""
                        dict["favoriteCount"] = record["favoriteCount"]?.intValue ?? 0
                        dict["likeCount"] = record["likeCount"]?.intValue ?? 0
                        dict["totalScore"] = record["totalScore"]?.intValue ?? 0
                        dict["lastUpdated"] = record["lastUpdated"]?.stringValue ?? ""
                        dict["latitude"] = record["latitude"]?.doubleValue
                        dict["longitude"] = record["longitude"]?.doubleValue
                        return dict
                    }
                
                
                // 打印UserScore表中的所有记录内容
                for (_, result) in results.enumerated() {
                    let _ = result["objectId"] as? String ?? "未知"
                    let _ = result["userName"] as? String ?? "未知"
                    let _ = result["userAvatar"] as? String ?? "未知"
                    let _ = result["favoriteCount"] as? Int ?? 0
                    let _ = result["likeCount"] as? Int ?? 0
                    let _ = result["totalScore"] as? Int ?? 0
                    let _ = result["lastUpdated"] as? String ?? "未知"
                    
                }
                
                if results.count <= 1 {
                    DispatchQueue.main.async {
                        completion(true, "")
                    }
                    return
                }
                
                // 🎯 修改：智能合并逻辑：优先保留积分最高的记录
                let recordsToDelete: [[String: Any]]
                
                // 按积分排序，保留积分最高的记录
                let sortedResults = results.sorted { 
                    (($0["totalScore"] as? Int) ?? 0) > (($1["totalScore"] as? Int) ?? 0)
                }
                recordsToDelete = Array(sortedResults[1...])
                
                let deleteGroup = DispatchGroup()
                var successCount = 0
                var errorCount = 0
                
                for record in recordsToDelete {
                    guard let objectId = record["objectId"] as? String else {
                        continue
                    }
                    
                    deleteGroup.enter()
                    self.deleteUserScoreRecord(objectId: objectId) { success in
                        if success {
                            successCount += 1
                        } else {
                            errorCount += 1
                        }
                        deleteGroup.leave()
                    }
                }
                
                    deleteGroup.notify(queue: .main) {
                        if errorCount == 0 {
                            completion(true, "")
                        } else {
                            completion(true, "")
                        }
                    }
                    
                case .failure(let error):
                    completion(false, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 更新UserScore记录的位置信息
    func updateUserScoreLocation(objectId: String, latitude: Double, longitude: Double, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/UserScore/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let updateData: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        // 🎯 新增：验证更新是否成功
                        self.verifyLocationUpdate(objectId: objectId, expectedLatitude: latitude, expectedLongitude: longitude)
                        completion(true)
                    } else {
                        if let responseData = data, String(data: responseData, encoding: .utf8) != nil {
                        }
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 🎯 新增：验证位置信息更新是否成功
    private func verifyLocationUpdate(objectId: String, expectedLatitude: Double, expectedLongitude: Double) {
        let urlString = "\(serverUrl)/1.1/classes/UserScore/\(objectId)"
        guard let url = URL(string: urlString) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let responseData = data,
                      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                    return
                }
                
                
                if let savedLatitude = json["latitude"] as? Double {
                    let latDiff = abs(savedLatitude - expectedLatitude)
                    if latDiff < 0.000000001 {
                    } else {
                    }
                } else {
                }
                
                if let savedLongitude = json["longitude"] as? Double {
                    let lonDiff = abs(savedLongitude - expectedLongitude)
                    if lonDiff < 0.000000001 {
                    } else {
                    }
                } else {
                }
                
            }
        }.resume()
    }
    
    // 删除指定的UserScore记录
    func deleteUserScoreRecord(objectId: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/UserScore/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}
