import Foundation
import LeanCloud

extension FriendshipManager {
    // MARK: - REST API 实现 - 好友列表相关
    
    /**
     * 查询好友列表API（符合 LeanCloud 好友关系开发指南）
     * 
     * API: GET /users/<user_id>/followees
     * 查询条件：
     * - where={"friendStatus": true} 查询双向好友
     * - include=followee 获取好友用户信息（followee 字段为 Pointer 类型）
     * 
     * 支持标准查询参数：where、order、skip、limit、count、include 等
     * 返回格式：{results: [数组结果]}
     */
    func queryFriendsListAPI(whereCondition: [String: Any], completion: @escaping ([UserInfo]?, Error?) -> Void) {
        // 获取当前用户的 LeanCloud objectId
        guard let currentUser = LCApplication.default.currentUser else {
            completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"]))
            return
        }
        
        let currentUserObjectId = currentUser.objectId?.value ?? ""
        
        let urlString = "\(config.leanCloudServerUrl)/1.1/users/\(currentUserObjectId)/followees"
        
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(config.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
        
        // 添加用户session token
        if let currentUser = LCApplication.default.currentUser,
           let sessionToken = currentUser.sessionToken?.value {
            request.setValue(sessionToken, forHTTPHeaderField: "X-LC-Session")
        }
        
        // 添加查询参数（注意：不要双重编码）
        do {
            let whereData = try JSONSerialization.data(withJSONObject: whereCondition)
            let whereString = String(data: whereData, encoding: .utf8) ?? "{}"
            
            
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            // URLQueryItem 会自动进行 URL 编码，所以这里不需要手动编码
            components?.queryItems = [
                URLQueryItem(name: "where", value: whereString),
                URLQueryItem(name: "include", value: "followee")
            ]
            
            if let finalURL = components?.url {
                request.url = finalURL
            } else {
            }
        } catch {
            completion(nil, error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard response as? HTTPURLResponse != nil else {
                completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的响应"]))
                return
            }
            
            
            guard let data = data else {
                completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无数据返回"]))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    if let results = json["results"] as? [[String: Any]] {
                        
                        let friends = results.compactMap { data -> UserInfo? in
                            
                            if let followeeData = data["followee"] as? [String: Any] {
                                
                                let objectId = followeeData["objectId"] as? String ?? ""
                                let username = followeeData["username"] as? String ?? ""
                                
                                // 🔧 修复：统一使用 objectId 作为 userId（与之前统一逻辑一致）
                                // 1. 游客用户：username 格式为 "guest_设备ID"，但我们也使用 objectId 作为 userId
                                // 2. 内部用户：使用 objectId 作为 userId（不再使用 username）
                                // 3. Apple 用户：使用 objectId 作为 userId（不再使用 authData 中的 id）
                                // 🎯 修改：不再读取 displayName，因为真实的用户名应该从 UserNameRecord 表获取
                                let loginType: UserInfo.LoginType
                                
                                if username.hasPrefix("guest_") {
                                    // 游客用户
                                    loginType = .guest
                                } else if followeeData["_authData_apple"] != nil {
                                    // Apple 用户
                                    loginType = .apple
                                } else {
                                    // 其他情况默认为游客
                                    loginType = .guest
                                }
                                
                                // 🔧 统一使用 objectId 作为 userId
                                let realUserId = objectId.isEmpty ? username : objectId
                                
                                // 🎯 修改：不再使用 _Followee 表的 displayName，使用空字符串作为占位符
                                // 真实的用户名应该从 UserNameRecord 表获取，而不是从 _Followee 表
                                // 这样可以避免显示错误的用户名（如 objectId 或 username）
                                let userInfo = UserInfo(
                                    id: objectId,
                                    userId: realUserId,  // 🔧 统一使用 objectId 作为 userId
                                    fullName: "",  // 🎯 修改：使用空字符串，不从 _Followee 表的 displayName 获取
                                    email: followeeData["email"] as? String,
                                    loginType: loginType
                                )
                                
                                return userInfo
                            } else {
                                return nil
                            }
                        }
                        
                        completion(friends, nil)
                    } else {
                        completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据解析失败"]))
                    }
                } else {
                    completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据解析失败"]))
                }
            } catch {
                if String(data: data, encoding: .utf8) != nil {
                }
                completion(nil, error)
            }
        }.resume()
    }
    
    /**
     * 修改好友属性API（符合 LeanCloud 好友关系开发指南）
     * 
     * API: PUT /users/<user_id>/friendship/<friend_id>
     * 参数：
     * - user_id: 用户的 objectId（如果设置了 X-LC-Session 头，可以使用 self）
     * - friend_id: 好友的 objectId
     * - friendship: json 对象，用于更新 _Followee 表中的自定义属性
     * 
     * 属性会被存储到 _Followee 表的相应列中
     */
    func updateFriendAttributesAPI(userId: String, friendId: String, attributes: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(config.leanCloudServerUrl)/1.1/users/\(userId)/friendship/\(friendId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(config.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
        
        // 添加用户session token
        if let currentUser = LCApplication.default.currentUser,
           let sessionToken = currentUser.sessionToken?.value {
            request.setValue(sessionToken, forHTTPHeaderField: "X-LC-Session")
        }
        
        do {
            let requestData: [String: Any] = ["friendship": attributes]
            let jsonData = try JSONSerialization.data(withJSONObject: requestData)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "无效的响应")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    completion(true, nil)
                } else {
                    let errorMessage = "服务器错误: \(httpResponse.statusCode)"
                    completion(false, errorMessage)
                }
            }.resume()
        } catch {
            completion(false, "数据格式错误")
        }
    }
    
    /**
     * 删除好友API（符合 LeanCloud 好友关系开发指南）
     * 
     * API: DELETE /users/<user_id>/friendship/<target_id>
     * 参数：
     * - user_id: 发起删除动作的用户的 objectId（如果设置了 X-LC-Session 头，可以使用 self）
     * - target_id: 要删除的朋友的 objectId
     * 
     * 注意：删除好友只会删掉 _Followee 表中当前用户的好友数据，对方的好友数据依然保留
     */
    func removeFriendAPI(userId: String, friendId: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(config.leanCloudServerUrl)/1.1/users/\(userId)/friendship/\(friendId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(config.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(config.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
        
        // 添加用户session token
        if let currentUser = LCApplication.default.currentUser,
           let sessionToken = currentUser.sessionToken?.value {
            request.setValue(sessionToken, forHTTPHeaderField: "X-LC-Session")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "网络错误: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "无效的响应")
                return
            }
            
            if httpResponse.statusCode == 200 {
                completion(true, nil)
            } else {
                let errorMessage = "服务器错误: \(httpResponse.statusCode)"
                completion(false, errorMessage)
            }
        }.resume()
    }
}

