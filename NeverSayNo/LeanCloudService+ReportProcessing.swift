//
//  LeanCloudService+ReportProcessing.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud
import UIKit

// MARK: - 举报记录处理功能
extension LeanCloudService {
    
    // 处理举报记录
    func processReportRecord(recordId: String, action: String, completion: @escaping (Bool, String?) -> Void) {
        
        // 首先获取举报记录的完整内容
        fetchReportRecordDetails(recordId: recordId) { [weak self] recordData, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, "获取举报记录详情失败: \(error)")
                return
            }
            
            guard let recordData = recordData else {
                completion(false, "未找到举报记录")
                return
            }
            
            // 将举报记录内容加上处理结果上传到新表
            self.uploadProcessedReportRecord(originalRecord: recordData, action: action, completion: completion)
        }
    }
    
    // 获取举报记录详情
    private func fetchReportRecordDetails(recordId: String, completion: @escaping ([String: Any]?, String?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/ReportRecord/\(recordId)"
        guard let url = URL(string: urlString) else {
            completion(nil, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                completion(json, nil)
                            } catch {
                                completion(nil, "解析响应数据失败: \(error)")
                            }
                        } else {
                            completion(nil, "无响应数据")
                        }
                    } else {
                        completion(nil, "服务器错误: \(httpResponse.statusCode)")
                    }
                } else {
                    completion(nil, "无效的响应")
                }
            }
        }.resume()
    }
    
    // 上传处理后的举报记录到新表 - 使用 LCObject
    private func uploadProcessedReportRecord(originalRecord: [String: Any], action: String, completion: @escaping (Bool, String?) -> Void) {
        // ✅ 使用 LCObject 创建对象
        let processedRecord = LCObject(className: "ProcessedReportRecord")
        
        do {
            // 复制原始记录的所有字段
            for (key, value) in originalRecord {
                if key != "objectId" && key != "createdAt" && key != "updatedAt" && key != "ACL" {
                    // 根据值的类型进行转换
                if let stringValue = value as? String {
                    try processedRecord.set("original_\(key)", value: stringValue)
                } else if let intValue = value as? Int {
                    try processedRecord.set("original_\(key)", value: intValue)
                } else if let doubleValue = value as? Double {
                    try processedRecord.set("original_\(key)", value: doubleValue)
                } else if let boolValue = value as? Bool {
                    try processedRecord.set("original_\(key)", value: boolValue)
                }
                // 忽略其他类型的值
            }
        }
            
            // 添加处理相关信息 + 处理者头像
            try processedRecord.set("processing_action", value: action)
            try processedRecord.set("processing_time", value: ISO8601DateFormatter().string(from: Date()))
            try processedRecord.set("processor_device_id", value: UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device")
            
            if let processorUserId = UserDefaults.standard.string(forKey: "current_user_id") {
                try processedRecord.set("processor_user_id", value: processorUserId)
                let loginType = UserDefaults.standard.string(forKey: "loginType") ?? "guest"
                let avatar = UserDefaults.standard.string(forKey: "custom_avatar_\(processorUserId)") ?? UserAvatarUtils.defaultAvatar(for: loginType)
                try processedRecord.set("processor_user_avatar", value: avatar)
            }
            
            _ = processedRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true, nil)
                    case .failure(let error):
                        // 如果是 404 错误（表不存在），尝试创建表
                        if error.code == 404 {
                            self.createProcessedReportRecordTable { tableCreated in
                                if tableCreated {
                                    self.uploadProcessedReportRecord(originalRecord: originalRecord, action: action, completion: completion)
                                } else {
                                    completion(false, "表创建失败")
                                }
                            }
                        } else {
                            completion(false, "上传失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } catch {
            completion(false, "属性设置失败: \(error.localizedDescription)")
        }
    }
    
    // 创建ProcessedReportRecord表
    private func createProcessedReportRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "original_reported_user_id": "test_user",
            "original_reported_user_name": "测试用户",
            "original_report_reason": "测试举报",
            "processing_action": "test_action",
            "processing_time": ISO8601DateFormatter().string(from: Date()),
            "processor_device_id": "test_device",
            "processor_user_id": "test_processor",
            "processor_user_avatar": "person.circle"
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/ProcessedReportRecord"
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
                                    self.deleteProcessedReportTestRecord(objectId: objectId) {
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
    
    // 删除ProcessedReportRecord测试记录
    private func deleteProcessedReportTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/ProcessedReportRecord/\(objectId)"
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
}
