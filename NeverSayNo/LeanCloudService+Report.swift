//
//  LeanCloudService+Report.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import UIKit
import LeanCloud

// MARK: - 举报管理扩展
extension LeanCloudService {
    
    // MARK: - 举报记录上传
    
    /// 上传举报记录到LeanCloud - 使用 LCObject
    func uploadReportRecord(reportData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        // ✅ 使用 LCObject 创建对象
        let reportRecord = LCObject(className: "ReportRecord")
        
        do {
            try reportRecord.set("reported_user_id", value: (reportData["reported_user_id"] as? String) ?? "")
            try reportRecord.set("reported_user_name", value: (reportData["reported_user_name"] as? String) ?? "")
            try reportRecord.set("reported_user_email", value: (reportData["reported_user_email"] as? String) ?? "")
            try reportRecord.set("reported_user_login_type", value: (reportData["reported_user_login_type"] as? String) ?? "")
            try reportRecord.set("report_reason", value: (reportData["report_reason"] as? String) ?? "")
            try reportRecord.set("report_time", value: (reportData["report_time"] as? String) ?? "")
            try reportRecord.set("reporter_user_id", value: (reportData["reporter_user_id"] as? String) ?? "")
            try reportRecord.set("reporter_user_name", value: (reportData["reporter_user_name"] as? String) ?? "")
            try reportRecord.set("reporter_user_email", value: (reportData["reporter_user_email"] as? String) ?? "")
            try reportRecord.set("reporter_login_type", value: (reportData["reporter_login_type"] as? String) ?? "")
            try reportRecord.set("deviceId", value: (reportData["deviceId"] as? String) ?? "")
            try reportRecord.set("status", value: "active")
            
            _ = reportRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true, "举报记录上传成功")
                    case .failure(let error):
                        completion(false, "上传失败: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            completion(false, "数据格式错误")
        }
    }
    
    /// 使用简化数据上传举报记录（已废弃，合并到 uploadReportRecord）
    private func uploadReportRecordWithSimplifiedData(reportData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        // 直接调用主方法
        uploadReportRecord(reportData: reportData, completion: completion)
    }
    
    // MARK: - 表创建
    
    /// 创建ReportRecord表
    private func createReportRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "reported_user_id": "test_user",
            "reported_user_name": "测试用户",
            "reported_user_email": "test@example.com",
            "reported_user_login_type": "test",
            "report_reason": "测试举报",
            "report_time": ISO8601DateFormatter().string(from: Date()),
            "reporter_user_id": "test_reporter",
            "reporter_user_name": "测试举报者",
            "reporter_user_email": "reporter@example.com",
            "reporter_login_type": "test",
            "deviceId": "test_device",
            "status": "active"
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/ReportRecord"
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
            let jsonData = try JSONSerialization.data(withJSONObject: testData)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
            
        } catch {
            completion(false)
        }
    }
}
