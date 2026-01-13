//
//  ContactInquiryManager.swift
//  NeverSayNo
//
//  询问联系方式是否真实管理器 - 基于LeanCloud REST API
//
//  核心表结构：
//  - ContactInquiry 表：存储所有询问记录，status 字段（pending/replied）
//
//  主要功能：
//  1. 发送询问：创建 ContactInquiry 记录，status 为 pending
//  2. 回复询问：更新 ContactInquiry 的 status 为 replied
//  3. 查询询问记录：查询 ContactInquiry 表
//

import Foundation
import LeanCloud
import UIKit

/**
 * 询问联系方式是否真实管理器
 * 基于LeanCloud REST API实现询问功能
 */
class ContactInquiryManager: ObservableObject {
    static let shared = ContactInquiryManager()
    
    // MARK: - 属性
    @Published var contactInquiries: [ContactInquiry] = []
    @Published var isLoading = false
    @Published var lastError: Error?
    
    // LeanCloud配置
    let config = Configuration.shared
    
    private init() {}
    
    // MARK: - 发送询问
    
    /**
     * 发送询问联系方式是否真实
     * - Parameters:
     *   - targetUserId: 目标用户ID（LeanCloud _User 表的 objectId）
     *   - completion: 完成回调
     */
    func sendContactInquiry(
        to targetUserId: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        isLoading = true
        lastError = nil
        
        // 获取当前用户的 LeanCloud objectId
        guard let currentUser = LCApplication.default.currentUser else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.lastError = NSError(domain: "ContactInquiryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
                completion(false, "用户未登录")
            }
            return
        }
        
        let currentUserObjectId = currentUser.objectId?.value ?? ""
        
        // 构建请求数据
        let requestData: [String: Any] = [
            "inquirer": [
                "__type": "Pointer",
                "className": "_User",
                "objectId": currentUserObjectId
            ],
            "targetUser": [
                "__type": "Pointer",
                "className": "_User",
                "objectId": targetUserId
            ],
            "status": "pending"
        ]
        
        // 发送REST API请求
        sendContactInquiryAPI(requestData: requestData) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    self?.lastError = nil
                    completion(true, "询问发送成功")
                } else {
                    self?.lastError = NSError(domain: "ContactInquiryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "发送失败"])
                    completion(false, errorMessage ?? "发送失败")
                }
            }
        }
    }
    
    // MARK: - REST API 实现
    
    /**
     * 发送询问API
     * API: POST /classes/ContactInquiry
     */
    private func sendContactInquiryAPI(requestData: [String: Any], completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(config.leanCloudServerUrl)/1.1/classes/ContactInquiry"
        
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
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "无效的响应")
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    completion(true, nil)
                } else {
                    let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "未知错误"
                    completion(false, "服务器错误: \(errorMessage)")
                }
            }
            
            task.resume()
        } catch {
            completion(false, "JSON序列化失败: \(error.localizedDescription)")
        }
    }
    
    /**
     * 查询询问记录
     * - Parameters:
     *   - status: 查询状态 (pending/replied)，nil表示查询所有状态
     *   - completion: 完成回调
     */
    func fetchContactInquiries(status: String? = nil, completion: @escaping ([ContactInquiry]?, Error?) -> Void) {
        isLoading = true
        lastError = nil
        
        // 获取当前用户的 LeanCloud objectId
        guard let currentUser = LCApplication.default.currentUser else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.lastError = NSError(domain: "ContactInquiryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
                completion(nil, self.lastError)
            }
            return
        }
        
        let currentUserObjectId = currentUser.objectId?.value ?? ""
        
        // 使用 $or 查询，包括：
        // 1. targetUser 指向当前用户（别人向当前用户发送的询问）
        // 2. inquirer 指向当前用户（当前用户发送的询问）
        var whereCondition: [String: Any] = [
            "$or": [
                [
                    "targetUser": [
                        "__type": "Pointer",
                        "className": "_User",
                        "objectId": currentUserObjectId
                    ]
                ],
                [
                    "inquirer": [
                        "__type": "Pointer",
                        "className": "_User",
                        "objectId": currentUserObjectId
                    ]
                ]
            ]
        ]
        
        // 如果指定了状态，添加状态过滤
        if let status = status {
            whereCondition["status"] = status
        }
        
        // 构建查询URL（参考 FriendshipManager 的实现）
        let urlString = "\(config.leanCloudServerUrl)/1.1/classes/ContactInquiry"
        
        do {
            let whereData = try JSONSerialization.data(withJSONObject: whereCondition)
            let whereString = String(data: whereData, encoding: .utf8) ?? "{}"
            
            var components = URLComponents(string: urlString)
            components?.queryItems = [
                URLQueryItem(name: "where", value: whereString),
                URLQueryItem(name: "order", value: "-createdAt"),
                URLQueryItem(name: "include", value: "inquirer,targetUser")
            ]
            
            guard let url = components?.url else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.lastError = NSError(domain: "ContactInquiryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
                    completion(nil, self.lastError)
                }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(config.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
            request.setValue(config.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
            
            // 添加用户session token
            if let currentUser = LCApplication.default.currentUser,
               let sessionToken = currentUser.sessionToken?.value {
                request.setValue(sessionToken, forHTTPHeaderField: "X-LC-Session")
            }
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.lastError = error
                        completion(nil, error)
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      let data = data else {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.lastError = NSError(domain: "ContactInquiryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
                        completion(nil, self?.lastError)
                    }
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let results = json["results"] as? [[String: Any]] {
                            let inquiries = results.compactMap { ContactInquiry(from: $0) }
                            DispatchQueue.main.async {
                                self?.isLoading = false
                                self?.lastError = nil
                                self?.contactInquiries = inquiries
                                completion(inquiries, nil)
                            }
                        } else {
                            DispatchQueue.main.async {
                                self?.isLoading = false
                                self?.lastError = NSError(domain: "ContactInquiryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据格式错误"])
                                completion(nil, self?.lastError)
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            self?.lastError = error
                            completion(nil, error)
                        }
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.lastError = NSError(domain: "ContactInquiryManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        completion(nil, self?.lastError)
                    }
                }
            }
            
            task.resume()
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.lastError = NSError(domain: "ContactInquiryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL构建失败: \(error.localizedDescription)"])
                completion(nil, self.lastError)
            }
            return
        }
    }
    
    /**
     * 根据询问者和被询问者查找并更新询问状态为已回复
     * - Parameters:
     *   - inquirerId: 询问者ID（发送询问的用户）
     *   - targetUserId: 被询问者ID（接收询问的用户，即当前用户）
     *   - completion: 完成回调，返回是否成功和询问记录ID（如果找到）
     */
    func markAsRepliedByUsers(inquirerId: String, targetUserId: String, completion: @escaping (Bool, String?) -> Void) {
        // 先查询找到对应的记录
        let urlString = "\(config.leanCloudServerUrl)/1.1/classes/ContactInquiry"
        
        do {
            let whereCondition: [String: Any] = [
                "inquirer": [
                    "__type": "Pointer",
                    "className": "_User",
                    "objectId": inquirerId
                ],
                "targetUser": [
                    "__type": "Pointer",
                    "className": "_User",
                    "objectId": targetUserId
                ],
                "status": "pending"
            ]
            
            let whereData = try JSONSerialization.data(withJSONObject: whereCondition)
            let whereString = String(data: whereData, encoding: .utf8) ?? "{}"
            
            var components = URLComponents(string: urlString)
            components?.queryItems = [
                URLQueryItem(name: "where", value: whereString),
                URLQueryItem(name: "limit", value: "1"),
                URLQueryItem(name: "order", value: "-createdAt")
            ]
            
            guard let url = components?.url else {
                completion(false, "无效的URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(config.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
            request.setValue(config.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
            
            // 添加用户session token
            if let currentUser = LCApplication.default.currentUser,
               let sessionToken = currentUser.sessionToken?.value {
                request.setValue(sessionToken, forHTTPHeaderField: "X-LC-Session")
            }
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      let data = data else {
                    completion(false, "无效的响应")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let results = json["results"] as? [[String: Any]],
                           let firstResult = results.first,
                           let inquiryId = firstResult["objectId"] as? String {
                            // 找到记录，更新状态
                            self.markAsReplied(inquiryId: inquiryId, completion: completion)
                        } else {
                            // 没有找到记录
                            completion(false, "未找到对应的询问记录")
                        }
                    } catch {
                        completion(false, "数据解析失败: \(error.localizedDescription)")
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                    completion(false, "服务器错误: \(errorMessage)")
                }
            }
            
            task.resume()
        } catch {
            completion(false, "查询条件构建失败: \(error.localizedDescription)")
        }
    }
    
    /**
     * 更新询问状态为已回复
     * - Parameters:
     *   - inquiryId: 询问记录ID
     *   - completion: 完成回调
     */
    func markAsReplied(inquiryId: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(config.leanCloudServerUrl)/1.1/classes/ContactInquiry/\(inquiryId)"
        
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
        
        let requestData: [String: Any] = [
            "status": "replied"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestData)
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "无效的响应")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    completion(true, nil)
                } else {
                    let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "未知错误"
                    completion(false, "服务器错误: \(errorMessage)")
                }
            }
            
            task.resume()
        } catch {
            completion(false, "JSON序列化失败: \(error.localizedDescription)")
        }
    }
}
