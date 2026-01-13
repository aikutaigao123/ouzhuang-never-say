import Foundation
import LeanCloud

extension FriendshipManager {
    // MARK: - 用户搜索
    
    /// 根据用户名搜索用户（从 UserNameRecord 表获取，并返回 userId）
    /// - Parameters:
    ///   - name: 搜索关键字
    ///   - excludingUserId: 排除的用户 objectId
    ///   - completion: 返回用户列表或错误
    func searchUsers(
        byName name: String,
        excludingUserId: String,
        completion: @escaping ([UserInfo]?, Error?) -> Void
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion([], nil)
            return
        }
        
        let urlString = "\(LeanCloudService.shared.serverUrl)/1.1/classes/UserNameRecord"
        guard var components = URLComponents(string: urlString) else {
            completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"]))
            return
        }
        
        // 构造 where 查询：userId 不等于当前用户，userName 或 userEmail 包含关键字
        let whereDict: [String: Any] = [
            "$and": [
                ["userId": ["$ne": excludingUserId]],
                [
                    "$or": [
                        ["userName": ["$regex": trimmed, "$options": "i"]],
                        ["userEmail": ["$regex": trimmed, "$options": "i"]]
                    ]
                ]
            ]
        ]
        
        do {
            let whereData = try JSONSerialization.data(withJSONObject: whereDict)
            let whereString = String(data: whereData, encoding: .utf8) ?? "{}"
            
            components.queryItems = [
                URLQueryItem(name: "where", value: whereString),
                URLQueryItem(name: "limit", value: "50")
            ]
        } catch {
            completion(nil, error)
            return
        }
        
        guard let url = components.url else {
            completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        LeanCloudService.shared.setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的响应"]))
                }
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    let errorMessage = "服务器错误: \(httpResponse.statusCode)"
                    completion(nil, NSError(domain: "FriendshipManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "FriendshipManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无数据返回"]))
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    
                    var users: [UserInfo] = []
                    
                    for record in results {
                        guard let userId = record["userId"] as? String,
                              !userId.isEmpty else {
                            continue
                        }
                        
                        let userName = record["userName"] as? String ?? ""
                        let userEmail = record["userEmail"] as? String
                        
                        // 推断登录类型
                        let loginType: UserInfo.LoginType
                        if userId.hasPrefix("guest_") || userId.contains("guest_") {
                            loginType = .guest
                        } else {
                            // 需要查询 _User 表来确定登录类型
                            // 这里先假设为游客，实际使用时可能需要进一步查询
                            loginType = .guest
                        }
                        
                        let userInfo = UserInfo(
                            id: userId,
                            userId: userId,
                            fullName: userName.isEmpty ? "未知用户" : userName,
                            email: userEmail,
                            loginType: loginType
                        )
                        
                        users.append(userInfo)
                    }
                    
                    DispatchQueue.main.async {
                        completion(users, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion([], nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }.resume()
    }
}

