import Foundation
import LeanCloud

// MARK: - 表管理扩展
extension LeanCloudService {
    
    // 创建UserScore表
    func createUserScoreTable(completion: @escaping (Bool) -> Void) {
        let testData: [String: Any] = [
            "userId": "test_user",
            "userName": "测试用户",
            "userAvatar": "😀",
            "userEmail": "test@example.com",
            "loginType": "guest",
            "totalScore": 0,
            "favoriteCount": 0,
            "likeCount": 0,
            "distance": 0.0,
            "lastUpdated": ISO8601DateFormatter().string(from: Date())
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/UserScore"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testData)
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
                    if httpResponse.statusCode == 201 {
                        // 删除测试记录
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let objectId = json?["objectId"] as? String {
                                    self.deleteUserScoreTestRecord(objectId: objectId) {
                                        completion(true)
                                    }
                                } else {
                                    completion(true)
                                }
                            } catch {
                                completion(true)
                            }
                        } else {
                            completion(true)
                        }
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 删除UserScore测试记录
    private func deleteUserScoreTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/UserScore/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
    
    // 获取用户收到的点赞数量 - 遵循数据存储开发指南，使用 LCQuery
    func getUserLikeCount(userId: String, completion: @escaping (Int, String) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "LikeRecord")
        query.whereKey("likedUserId", .equalTo(userId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 0 // 仅用于计数
        
        query.count { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    completion(count, "")
                case .failure(let error):
                    completion(0, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
