//
//  LeanCloudService+ReportRecords.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 举报记录数据模型和获取功能
extension LeanCloudService {
    
    // 举报记录数据模型
    struct LeanCloudReportRecord {
        let id: String
        let reporterUserId: String
        let reporterUserName: String
        let reportedUserId: String
        let reportedUserName: String
        let reportedUserEmail: String
        let reportedUserLoginType: String? // 被举报用户的用户类型
        let reportedUserAvatar: String?    // 被举报用户头像（真实头像表情）
        let reportReason: String
        let reportTime: Date
    }
    
    // 获取举报记录列表
    func fetchReportRecords(completion: @escaping ([LeanCloudReportRecord]?, String?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/ReportRecord?order=-createdAt&limit=100"
        
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
                    if httpResponse.statusCode == 200, let data = data {
                        
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]] {
                                
                                var reportRecords: [LeanCloudReportRecord] = []
                                for record in results {
                                    if let reportRecord = self.parseReportRecord(from: record) {
                                        reportRecords.append(reportRecord)
                                    }
                                }
                                
                                completion(reportRecords, nil)
                            } else {
                                completion([], nil)
                            }
                        } catch {
                            completion(nil, "解析响应失败: \(error.localizedDescription)")
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
    
    // 解析举报记录
    private func parseReportRecord(from record: [String: Any]) -> LeanCloudReportRecord? {
        guard let objectId = record["objectId"] as? String,
              let reporterUserName = record["reporter_user_name"] as? String,
              let reportedUserName = record["reported_user_name"] as? String,
              let reportReason = record["report_reason"] as? String,
              let reportTimeString = record["report_time"] as? String else {
            return nil
        }
        
        // 解析举报时间
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let reportTime = formatter.date(from: reportTimeString) ?? Date()
        
        // 获取其他可选字段
        let reporterUserId = record["reporter_user_id"] as? String ?? ""
        let reportedUserId = record["reported_user_id"] as? String ?? ""
        let reportedUserEmail = record["reported_user_email"] as? String ?? ""
        let reportedUserLoginType = record["reported_user_login_type"] as? String
        let reportedUserAvatar = record["reported_user_avatar"] as? String
        
        return LeanCloudReportRecord(
            id: objectId,
            reporterUserId: reporterUserId,
            reporterUserName: reporterUserName,
            reportedUserId: reportedUserId,
            reportedUserName: reportedUserName,
            reportedUserEmail: reportedUserEmail,
            reportedUserLoginType: reportedUserLoginType,
            reportedUserAvatar: reportedUserAvatar,
            reportReason: reportReason,
            reportTime: reportTime
        )
    }
}
