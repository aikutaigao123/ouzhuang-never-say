//
//  LeanCloudService+MatchRecordUpload.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import CoreLocation
import UIKit
import LeanCloud

// MARK: - Match Record Upload Extensions
extension LeanCloudService {
    
    /// 上传匹配记录
    func uploadMatchRecord(user1Id: String, user1Name: String, user1Avatar: String, user1LoginType: String,
                          user2Id: String, user2Name: String, user2Avatar: String, user2LoginType: String,
                          matchTime: Date, matchLocation: CLLocation?, completion: @escaping (Bool, String) -> Void) {
        
        // 确保表存在
        ensureMatchRecordTableExists { [weak self] tableExists in
            guard let self = self, tableExists else {
                completion(false, "表创建失败")
                return
            }
            
            // 创建匹配记录
            let matchRecord = MatchRecord(
                user1Id: user1Id,
                user2Id: user2Id,
                user1Name: user1Name,
                user2Name: user2Name,
                user1Avatar: user1Avatar,
                user2Avatar: user2Avatar,
                user1LoginType: user1LoginType,
                user2LoginType: user2LoginType,
                matchTime: matchTime,
                matchLocation: matchLocation.map { CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) },
                status: "active",
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "",
                timezone: TimeZone.current.identifier,
                deviceTime: Date()
            )
            
            // 上传到LeanCloud
            self.uploadMatchRecordToLeanCloud(matchRecord) { success in
                completion(success, success ? "上传成功" : "上传失败")
            }
        }
    }
    
    /// 自动检测并上传匹配记录
    func autoDetectAndUploadMatchRecords(for currentUserId: String, completion: @escaping (Bool) -> Void) {
        // 获取所有消息
        fetchAllRecordsForClass(className: "Message") { [weak self] messages, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            if error != nil {
                completion(false)
                return
            }
            
            guard let messages = messages else {
                completion(false)
                return
            }
            
            // 分析消息生成匹配记录
            let matchRecords = self.analyzeMessagesForCurrentUser(currentUserId, messages)
            
            if matchRecords.isEmpty {
                completion(true)
                return
            }
            
            // 过滤已上传的记录
            let newMatchRecords = matchRecords.filter { !self.hasMatchRecordBeenUploaded($0) }
            
            if newMatchRecords.isEmpty {
                completion(true)
                return
            }
            
            // 上传新记录
            self.uploadMatchRecords(newMatchRecords) { success in
                completion(success)
            }
        }
    }
    
    /// 检查匹配记录是否已上传
    private func hasMatchRecordBeenUploaded(_ matchRecord: MatchRecord) -> Bool {
        let key = "match_uploaded_\(matchRecord.user1Id)_\(matchRecord.user2Id)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    /// 清除所有匹配记录上传标志
    func clearAllMatchRecordUploadFlags() {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("match_uploaded_") {
                defaults.removeObject(forKey: key)
            }
        }
    }
    
    /// 清除特定匹配记录的上传标志
    func clearMatchRecordUploadFlag(user1Id: String, user2Id: String) {
        let key = "match_uploaded_\(user1Id)_\(user2Id)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// 上传匹配记录数组
    private func uploadMatchRecords(_ matchRecords: [MatchRecord], completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var successCount = 0
        
        for matchRecord in matchRecords {
            group.enter()
            uploadMatchRecordToLeanCloud(matchRecord) { success in
                if success {
                    successCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(successCount > 0)
        }
    }
    
    /// 上传单个匹配记录到LeanCloud - 遵循数据存储开发指南，使用 LCObject
    private func uploadMatchRecordToLeanCloud(_ matchRecord: MatchRecord, completion: @escaping (Bool) -> Void) {
        // ✅ 按照开发指南：使用 LCObject 创建对象
        let matchRecordObject = LCObject(className: "MatchRecord")
        
        do {
            // ✅ 按照开发指南：设置属性值
            try matchRecordObject.set("user1Id", value: matchRecord.user1Id)
            try matchRecordObject.set("user2Id", value: matchRecord.user2Id)
            try matchRecordObject.set("user1Name", value: matchRecord.user1Name)
            try matchRecordObject.set("user2Name", value: matchRecord.user2Name)
            try matchRecordObject.set("user1Avatar", value: matchRecord.user1Avatar)
            try matchRecordObject.set("user2Avatar", value: matchRecord.user2Avatar)
            try matchRecordObject.set("user1LoginType", value: matchRecord.user1LoginType)
            try matchRecordObject.set("user2LoginType", value: matchRecord.user2LoginType)
            try matchRecordObject.set("matchTime", value: ISO8601DateFormatter().string(from: matchRecord.matchTime))
            try matchRecordObject.set("matchLocationLat", value: matchRecord.matchLocationLat)
            try matchRecordObject.set("matchLocationLng", value: matchRecord.matchLocationLng)
            try matchRecordObject.set("status", value: matchRecord.status)
            try matchRecordObject.set("deviceId", value: matchRecord.deviceId)
            try matchRecordObject.set("timezone", value: matchRecord.timezone)
            try matchRecordObject.set("deviceTime", value: ISO8601DateFormatter().string(from: matchRecord.deviceTime))
            
            // ✅ 按照开发指南：将对象保存到云端
            
            _ = matchRecordObject.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // 标记为已上传
                        let key = "match_uploaded_\(matchRecord.user1Id)_\(matchRecord.user2Id)"
                        UserDefaults.standard.set(true, forKey: key)
                        completion(true)
                    case .failure:
                        completion(false)
                    }
                }
            }
        } catch {
            completion(false)
        }
    }
}
