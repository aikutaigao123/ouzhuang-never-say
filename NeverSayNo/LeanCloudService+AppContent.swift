import Foundation
import LeanCloud

// MARK: - 应用内容管理扩展
extension LeanCloudService {
    
    // 从LeanCloud获取用户协议 - 使用 LCQuery
    func fetchTermsOfService(completion: @escaping (String?, String?) -> Void) {
        // ✅ 使用 LCQuery 查询
        let query = LCQuery(className: "AppContent")
        query.whereKey("type", .equalTo("terms_of_service"))
        query.whereKey("updatedAt", .descending)
        query.limit = 1
        
        _ = query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let objects):
                    if let firstObject = objects.first,
                       let content = firstObject["content"]?.stringValue {
                        completion(content, nil)
                    } else {
                        completion(nil, "未找到用户协议内容")
                    }
                case .failure(let error):
                    // 如果是 404 错误（表不存在），尝试创建表
                    if error.code == 404 {
                        self.createAppContentTable { tableCreated in
                            if tableCreated {
                                self.fetchTermsOfService(completion: completion)
                            } else {
                                completion(nil, "表创建失败")
                            }
                        }
                    } else {
                        completion(nil, "获取失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // 从LeanCloud获取隐私政策 - 使用 LCQuery
    func fetchPrivacyPolicy(completion: @escaping (String?, String?) -> Void) {
        // ✅ 使用 LCQuery 查询
        let query = LCQuery(className: "AppContent")
        query.whereKey("type", .equalTo("privacy_policy"))
        query.whereKey("updatedAt", .descending)
        query.limit = 1
        
        _ = query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let objects):
                    if let firstObject = objects.first,
                       let content = firstObject["content"]?.stringValue {
                        completion(content, nil)
                    } else {
                        completion(nil, "未找到隐私政策内容")
                    }
                case .failure(let error):
                    // 如果是 404 错误（表不存在），尝试创建表
                    if error.code == 404 {
                        self.createAppContentTable { tableCreated in
                            if tableCreated {
                                self.fetchPrivacyPolicy(completion: completion)
                            } else {
                                completion(nil, "表创建失败")
                            }
                        }
                    } else {
                        completion(nil, "获取失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
