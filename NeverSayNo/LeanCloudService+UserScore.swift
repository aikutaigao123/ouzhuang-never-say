import Foundation
import UIKit

// MARK: - 基础积分操作扩展
extension LeanCloudService {
    
    // 上传或更新用户积分（自动合并重复记录）
    func uploadUserScore(userScore: UserScore, completion: @escaping (Bool, String) -> Void) {
        uploadUserScore(userScore: userScore, locationRecordLatitude: nil, locationRecordLongitude: nil, completion: completion)
    }
    
    // 上传或更新用户积分（带LocationRecord坐标对比）
    func uploadUserScore(userScore: UserScore, locationRecordLatitude: Double?, locationRecordLongitude: Double?, completion: @escaping (Bool, String) -> Void) {
        
        
        // 🎯 修改：先查询是否存在该用户的UserScore记录
        self.findExistingUserScoreRecord(userId: userScore.id, loginType: userScore.loginType) { existingObjectId in
            if let objectId = existingObjectId {
                // 存在记录，使用 PUT 更新
                self.updateUserScoreRecord(objectId: objectId, userScore: userScore, locationRecordLatitude: locationRecordLatitude, locationRecordLongitude: locationRecordLongitude, completion: completion)
            } else {
                // 不存在记录，使用 POST 创建
                self.createUserScoreRecord(userScore: userScore, locationRecordLatitude: locationRecordLatitude, locationRecordLongitude: locationRecordLongitude, completion: completion)
            }
        }
    }
    
    // 🎯 新增：查找现有的UserScore记录
    private func findExistingUserScoreRecord(userId: String, loginType: String, completion: @escaping (String?) -> Void) {
        guard let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let whereClause = "{\"userId\":\"\(encodedUserId)\",\"loginType\":\"\(loginType)\"}".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(nil)
            return
        }
        
        let queryUrlString = "\(serverUrl)/1.1/classes/UserScore?where=\(whereClause)&limit=1&order=-lastUpdated"
        guard let queryUrl = URL(string: queryUrlString) else {
            completion(nil)
            return
        }
        
        var queryRequest = URLRequest(url: queryUrl)
        queryRequest.httpMethod = "GET"
        setLeanCloudHeaders(&queryRequest)
        queryRequest.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: queryRequest) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let responseData = data,
                      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                      let results = json["results"] as? [[String: Any]],
                      let firstResult = results.first,
                      let objectId = firstResult["objectId"] as? String else {
                    completion(nil)
                    return
                }
                completion(objectId)
            }
        }.resume()
    }
    
    // 🎯 新增：创建新的UserScore记录
    private func createUserScoreRecord(userScore: UserScore, locationRecordLatitude: Double?, locationRecordLongitude: Double?, completion: @escaping (Bool, String) -> Void) {
        var scoreData: [String: Any] = [
            "userId": userScore.id,
            "userName": userScore.userName,
            "userEmail": userScore.userEmail ?? "",
            "loginType": userScore.loginType,
            "totalScore": userScore.totalScore,
            "favoriteCount": userScore.favoriteCount,
            "likeCount": userScore.likeCount,
            "lastUpdated": ISO8601DateFormatter().string(from: userScore.lastUpdated),
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        // 🎯 调试：打印实际上传的数据字典
        
        if let distance = userScore.distance {
            scoreData["distance"] = distance
        }
        
        if let latitude = userScore.latitude {
            scoreData["latitude"] = latitude
        }
        
        if let longitude = userScore.longitude {
            scoreData["longitude"] = longitude
        }
        
        let urlString = "\(serverUrl)/1.1/classes/UserScore"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let scoreDataWithACL = addACLToData(scoreData)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: scoreDataWithACL)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "上传失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    // 🎯 调试：打印服务器响应状态码
                    
                    if httpResponse.statusCode == 201 {
                        if let responseData = data {
                            // 🎯 调试：打印服务器返回的完整响应
                            
                            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                               let objectId = json["objectId"] as? String {
                                // ⚠️ 注意：LeanCloud的POST响应默认不返回所有字段，只返回objectId和createdAt
                                // 需要通过GET请求查询才能验证字段是否保存成功
                                
                                // 🎯 新增：上传成功后立即查询验证字段是否保存
                                self.verifyUserScoreFields(
                                    objectId: objectId,
                                    expectedTotalScore: userScore.totalScore,
                                    expectedLatitude: userScore.latitude,
                                    expectedLongitude: userScore.longitude,
                                    locationRecordLatitude: locationRecordLatitude,
                                    locationRecordLongitude: locationRecordLongitude
                                )
                            }
                        }
                        
                        self.mergeUserScoreRecords(userId: userScore.id, loginType: userScore.loginType) { mergeSuccess, mergeError in
                            if mergeSuccess {
                            } else {
                            }
                            completion(true, "")
                        }
                    } else if httpResponse.statusCode == 404 {
                        self.createUserScoreTable { tableCreated in
                            if tableCreated {
                                self.createUserScoreRecord(userScore: userScore, locationRecordLatitude: locationRecordLatitude, locationRecordLongitude: locationRecordLongitude, completion: completion)
                            } else {
                                completion(false, "表创建失败")
                            }
                        }
                        return
                    } else {
                        var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                                // 🎯 调试：打印错误响应
                            } catch {
                                errorMessage = "服务器错误: \(httpResponse.statusCode)"
                            }
                        }
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "无效的服务器响应")
                }
            }
        }.resume()
    }
    
    // 🎯 新增：更新现有的UserScore记录
    private func updateUserScoreRecord(objectId: String, userScore: UserScore, locationRecordLatitude: Double?, locationRecordLongitude: Double?, completion: @escaping (Bool, String) -> Void) {
        var scoreData: [String: Any] = [
            "userId": userScore.id,
            "userName": userScore.userName,
            "userEmail": userScore.userEmail ?? "",
            "loginType": userScore.loginType,
            "totalScore": userScore.totalScore,
            "favoriteCount": userScore.favoriteCount,
            "likeCount": userScore.likeCount,
            "lastUpdated": ISO8601DateFormatter().string(from: userScore.lastUpdated),
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        // 🎯 调试：打印实际上传的数据字典
        
        if let distance = userScore.distance {
            scoreData["distance"] = distance
        }
        
        if let latitude = userScore.latitude {
            scoreData["latitude"] = latitude
        }
        
        if let longitude = userScore.longitude {
            scoreData["longitude"] = longitude
        }
        
        let urlString = "\(serverUrl)/1.1/classes/UserScore/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let scoreDataWithACL = addACLToData(scoreData)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: scoreDataWithACL)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "更新失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    // 🎯 调试：打印服务器响应状态码
                    
                    if httpResponse.statusCode == 200 {
                        if data != nil {
                            // 🎯 调试：打印服务器返回的完整响应
                            
                            // 🎯 新增：更新成功后立即查询验证字段是否保存
                            self.verifyUserScoreFields(
                                objectId: objectId,
                                expectedTotalScore: userScore.totalScore,
                                expectedLatitude: userScore.latitude,
                                expectedLongitude: userScore.longitude,
                                locationRecordLatitude: locationRecordLatitude,
                                locationRecordLongitude: locationRecordLongitude
                            )
                        }
                        
                        completion(true, "")
                    } else {
                        var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                                // 🎯 调试：打印错误响应
                            } catch {
                                errorMessage = "服务器错误: \(httpResponse.statusCode)"
                            }
                        }
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "无效的服务器响应")
                }
            }
        }.resume()
    }
    
    // 合并指定用户的UserScore记录（供外部调用）
    func mergeCurrentUserScoreRecords(completion: @escaping (Bool, String) -> Void) {
        let userId = UserDefaults.standard.string(forKey: "current_user_id") ?? ""
        let loginType = UserDefaults.standard.string(forKey: "current_user_login_type") ?? "guest"
        
        if userId.isEmpty {
            completion(false, "无法获取当前用户ID")
            return
        }
        
        
        mergeUserScoreRecords(userId: userId, loginType: loginType) { success, error in
            if success {
                completion(true, "")
            } else {
                completion(false, error)
            }
        }
    }
    
    // 打印UserScore表的所有内容
    func printUserScoreTableContents(completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/UserScore?order=-lastUpdated&limit=100"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(false)
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let results = json?["results"] as? [[String: Any]] else {
                        completion(false)
                        return
                    }
                    
                    
                    for (_, result) in results.enumerated() {
                        let latitude = result["latitude"] as? Double
                        let longitude = result["longitude"] as? Double
                        
                        if latitude != nil && longitude != nil {
                        }
                    }
                    
                    completion(true)
                } catch {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 🎯 新增：验证UserScore字段是否保存成功
    private func verifyUserScoreFields(objectId: String, expectedTotalScore: Int, expectedLatitude: Double?, expectedLongitude: Double?, locationRecordLatitude: Double? = nil, locationRecordLongitude: Double? = nil) {
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
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    return
                }
                
                guard httpResponse.statusCode == 200,
                      let responseData = data,
                      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                    return
                }
                
                // 🎯 调试：打印查询到的完整数据
                
                // 🎯 验证所有字段
                let savedTotalScore = json["totalScore"] as? Int ?? 0
                let savedLatitude = json["latitude"] as? Double
                let savedLongitude = json["longitude"] as? Double
                
                // 🎯 验证 totalScore 是否更新
                if savedTotalScore != expectedTotalScore {
                } else {
                }
                
                
                // 🎯 新增：对比LocationRecord和UserScore的坐标
                if locationRecordLatitude != nil && locationRecordLongitude != nil {
                } else {
                }
                
                // 🎯 验证坐标
                if let savedLatitude = savedLatitude {
                    
                    // 与期望值对比
                    if let expectedLat = expectedLatitude {
                        let diff = abs(savedLatitude - expectedLat)
                        if diff < 0.000000001 {
                        } else {
                        }
                    }
                    
                    // 与LocationRecord坐标对比
                    if let locRecordLat = locationRecordLatitude {
                        let diff = abs(savedLatitude - locRecordLat)
                        if diff < 0.000000001 {
                        } else {
                        }
                    }
                } else {
                }
                
                if let savedLongitude = savedLongitude {
                    
                    // 与期望值对比
                    if let expectedLon = expectedLongitude {
                        let diff = abs(savedLongitude - expectedLon)
                        if diff < 0.000000001 {
                        } else {
                        }
                    }
                    
                    // 与LocationRecord坐标对比
                    if let locRecordLon = locationRecordLongitude {
                        let diff = abs(savedLongitude - locRecordLon)
                        if diff < 0.000000001 {
                        } else {
                        }
                    }
                } else {
                }
                
                // 🎯 总结对比结果
                var allFieldsValid = true
                
                // 验证 totalScore
                if savedTotalScore != expectedTotalScore {
                    allFieldsValid = false
                } else {
                }
                
                // 验证坐标
                if let savedLatitude = savedLatitude,
                   let savedLongitude = savedLongitude,
                   let locRecordLat = locationRecordLatitude,
                   let locRecordLon = locationRecordLongitude {
                    let latDiff = abs(savedLatitude - locRecordLat)
                    let lonDiff = abs(savedLongitude - locRecordLon)
                    if latDiff < 0.000000001 && lonDiff < 0.000000001 {
                    } else {
                    }
                }
                
                // 打印所有字段用于调试
                for _ in json.sorted(by: { $0.key < $1.key }) {
                }
                
                if allFieldsValid {
                } else {
                }
            }
        }.resume()
    }
}
