import Foundation
import LeanCloud

extension FriendshipManager {
    // MARK: - REST API 实现 - 好友申请相关
    
    /**
     * 发送好友申请API（符合 LeanCloud 好友关系开发指南）
     * 
     * API: POST /users/friendshipRequests
     * 请求体包含：
     * - user: Pointer 对象，指向发起申请的用户（必须与当前登录用户相同）
     * - friend: Pointer 对象，指向目标好友用户
     * - friendship: 可选，json 对象，用于在 _Followee 表存储自定义属性
     * 
     * 返回值：包含 _FriendshipRequest 表 objectId 的 JSON 数据
     */
    func sendFriendshipRequestAPI(requestData: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        
        let urlString = "\(config.leanCloudServerUrl)/1.1/users/friendshipRequests"
        
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(config.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
        
        // 添加用户session token
        if let currentUser = LCApplication.default.currentUser,
           let sessionToken = currentUser.sessionToken?.value {
            request.setValue(sessionToken, forHTTPHeaderField: "X-LC-Session")
        }
        
        
        do {
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
                
                if httpResponse.statusCode == 201 {
                    completion(true, nil)
                } else {
                    var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? String {
                        errorMessage = error
                    }
                    completion(false, errorMessage)
                }
            }.resume()
        } catch {
            completion(false, "数据格式错误: \(error.localizedDescription)")
        }
    }
    
    /**
     * 通过Apple credential.user查找LeanCloud _User表的objectId
     * 通过查询LoginRecord表的apple_auth_data_lc_apple_uid字段来查找
     */
    func findLeanCloudObjectIdFromAppleCredential(appleCredentialUser: String, completion: @escaping (String?) -> Void) {
        let urlString = "\(config.leanCloudServerUrl)/1.1/classes/LoginRecord"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // 构建查询条件：查找apple_auth_data_lc_apple_uid等于appleCredentialUser的记录
        let whereCondition: [String: Any] = [
            "apple_auth_data_lc_apple_uid": appleCredentialUser,
            "loginType": "apple"
        ]
        
        do {
            let whereData = try JSONSerialization.data(withJSONObject: whereCondition)
            let whereString = String(data: whereData, encoding: .utf8) ?? "{}"
            
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "where", value: whereString),
                URLQueryItem(name: "limit", value: "1"),
                URLQueryItem(name: "order", value: "-updatedAt")
            ]
            
            guard let finalURL = components?.url else {
                completion(nil)
                return
            }
            
            var request = URLRequest(url: finalURL)
            request.httpMethod = "GET"
            request.setValue(config.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
            request.setValue(config.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
            
            // 添加用户session token
            if let currentUser = LCApplication.default.currentUser,
               let sessionToken = currentUser.sessionToken?.value {
                request.setValue(sessionToken, forHTTPHeaderField: "X-LC-Session")
            }
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    completion(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(nil)
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]],
                       let firstResult = results.first,
                       let userId = firstResult["userId"] as? String {
                        completion(userId)
                        return
                    }
                    completion(nil)
                } else {
                    completion(nil)
                }
            }.resume()
        } catch {
            completion(nil)
        }
    }
    
    /**
     * 验证用户是否存在
     * 通过查询 _User 表来验证用户是否存在
     */
    func verifyUserExists(userId: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(config.leanCloudServerUrl)/1.1/users/\(userId)"
        
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(config.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
        
        // 添加用户session token（可选，但建议添加）
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
            } else if httpResponse.statusCode == 404 {
                completion(false, "用户不存在或使用了本地登录模式")
            } else {
                var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    errorMessage = error
                }
                completion(false, errorMessage)
            }
        }.resume()
    }
    
    /**
     * 查询好友申请API（符合 LeanCloud 好友关系开发指南）
     * 
     * API: GET /classes/_FriendshipRequest
     * 支持标准查询参数：where、order、skip、limit、count、include 等
     * 返回格式：{results: [数组结果]}
     * 
     * 建议使用 include 指定字段以获取用户信息（user 和 friend 字段为 Pointer 类型）
     */
    func queryFriendshipRequestsAPI(whereCondition: [String: Any], completion: @escaping ([FriendshipRequest]?, Error?) -> Void) {
        
        let urlString = "\(config.leanCloudServerUrl)/1.1/classes/_FriendshipRequest"
        
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
        } else {
        }
        
        // 添加查询参数（避免重复编码 where 参数）
        do {
            let whereData = try JSONSerialization.data(withJSONObject: whereCondition)
            let whereString = String(data: whereData, encoding: .utf8) ?? "{}"

            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "where", value: whereString),
                URLQueryItem(name: "include", value: "user,friend")
            ]

            if let finalURL = components?.url {
                request.url = finalURL
            }
        } catch {
            completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "查询参数序列化失败"]))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            // 先判断HTTP状态码，捕获429等错误
            if let httpResponse = response as? HTTPURLResponse {
                
                if httpResponse.statusCode != 200 {
                    let status = httpResponse.statusCode
                    var message = "服务器错误: \(status)"
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let errMsg = json["error"] as? String {
                        message = errMsg
                    }
                    completion(nil, NSError(domain: "FriendshipManager", code: status, userInfo: [NSLocalizedDescriptionKey: message]))
                    return
                }
            }

            guard let data = data else {
                completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无数据返回"]))
                return
            }
            
            if String(data: data, encoding: .utf8) != nil {
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let results = json["results"] as? [[String: Any]] {
                        let requests = results.compactMap { FriendshipRequest(from: $0) }
                        completion(requests, nil)
                    } else if let errorMessage = json["error"] as? String {
                        completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                    } else {
                        completion([], nil) // 返回空数组而不是nil
                    }
                } else {
                    completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据解析失败"]))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
    
    /**
     * 接受好友申请API（符合 LeanCloud 好友关系开发指南）
     * 
     * API: PUT /users/friendshipRequests/<request-object-id>/accept
     * 参数：
     * - request-object-id: 好友申请的 objectId（_FriendshipRequest 表的 objectId）
     * - friendship: 可选，json 对象，用于在 _Followee 表存储自定义属性
     * 
     * 返回值：包含 _FriendshipRequest 表 objectId 和 updatedAt 的 JSON 数据
     */
    func acceptFriendshipRequestAPI(requestId: String, requestData: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(config.leanCloudServerUrl)/1.1/users/friendshipRequests/\(requestId)/accept"
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
     * 拒绝好友申请API（符合 LeanCloud 好友关系开发指南）
     * 
     * API: PUT /users/friendshipRequests/<request-object-id>/decline
     * 参数：
     * - request-object-id: 好友申请的 objectId（_FriendshipRequest 表的 objectId）
     * 
     * 返回值：包含 _FriendshipRequest 表 objectId 和 updatedAt 的 JSON 数据
     * 注意：拒绝后，对方无法再次发起好友申请，除非找到被拒绝的申请并改为接受
     */
    func declineFriendshipRequestAPI(requestId: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(config.leanCloudServerUrl)/1.1/users/friendshipRequests/\(requestId)/decline"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
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
    
    /**
     * 删除好友申请API（符合 LeanCloud 好友关系开发指南）
     * 
     * API: DELETE /classes/_FriendshipRequest/<objectId>
     * 参数：
     * - objectId: 好友申请的 objectId（申请好友时返回的 objectId）
     * 
     * 返回值：删除成功返回空对象 {}
     */
    func deleteFriendshipRequestAPI(requestId: String, completion: @escaping (Bool, String?) -> Void) {
        
        let urlString = "\(config.leanCloudServerUrl)/1.1/classes/_FriendshipRequest/\(requestId)"
        
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
        } else {
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
            
            if let data = data {
                if String(data: data, encoding: .utf8) != nil {
                }
            }
            
            // 删除成功返回 200 或 204
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                completion(true, nil)
            } else {
                var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? String {
                    errorMessage = error
                }
                completion(false, errorMessage)
            }
        }.resume()
    }
}



