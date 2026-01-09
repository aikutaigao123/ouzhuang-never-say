import Foundation
import LeanCloud

// MARK: - 位置记录操作扩展
extension LeanCloudService {
    
    // 发送位置信息 - 遵循数据存储开发指南，使用 LCObject
    func sendLocationWithSimplifiedData(locationData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        let saveStartTime = Date()
        
        // 记录请求历史（如果 LeanCloudService+LocationService 中有追踪机制）
        
        // ✅ 按照开发指南：使用 LCObject 创建对象
        let locationRecord = LCObject(className: "LocationRecord")
        
        do {
            // ✅ 按照开发指南：设置属性值
            try locationRecord.set("latitude", value: locationData["latitude"] as? Double ?? 0.0)
            try locationRecord.set("longitude", value: locationData["longitude"] as? Double ?? 0.0)
            try locationRecord.set("accuracy", value: locationData["accuracy"] as? Double ?? 0.0)
            try locationRecord.set("userId", value: locationData["userId"] as? String ?? "")
            try locationRecord.set("userName", value: locationData["userName"] as? String ?? "")
            try locationRecord.set("loginType", value: locationData["loginType"] as? String ?? "")
            try locationRecord.set("userEmail", value: locationData["userEmail"] as? String ?? "")
            try locationRecord.set("deviceId", value: locationData["deviceId"] as? String ?? "")
            try locationRecord.set("timezone", value: locationData["timezone"] as? String ?? "UTC")
            try locationRecord.set("deviceTime", value: locationData["deviceTime"] as? String ?? ISO8601DateFormatter().string(from: Date()))
            
            // ✅ 按照开发指南：将对象保存到云端
            
            _ = locationRecord.save { result in
                let saveEndTime = Date()
                let _ = saveEndTime.timeIntervalSince(saveStartTime)
                
                DispatchQueue.main.async {
                    
                    switch result {
                    case .success:
                        completion(true, "位置信息发送成功")
                    case .failure(let error):
                        
                        // 检查是否是429错误
                        if error.code == 429 || (error.reason?.contains("429") ?? false) {
                        }
                        
                        completion(false, error.localizedDescription)
                    }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    // 创建LocationRecord字段 - 使用 LCObject
    func createLocationRecordFields(completion: @escaping (Bool) -> Void) {
        // ✅ 使用 LCObject 创建测试对象
        let locationRecord = LCObject(className: "LocationRecord")
        
        do {
            try locationRecord.set("latitude", value: 0.0)
            try locationRecord.set("longitude", value: 0.0)
            try locationRecord.set("accuracy", value: 0.0)
            try locationRecord.set("userId", value: "field_init")
            try locationRecord.set("userName", value: "Field Initialization")
            try locationRecord.set("loginType", value: "guest")
            try locationRecord.set("userEmail", value: "")
            try locationRecord.set("userAvatar", value: "person.circle")
            try locationRecord.set("deviceId", value: "field_init_device")
            try locationRecord.set("timezone", value: "UTC")
            try locationRecord.set("deviceTime", value: ISO8601DateFormatter().string(from: Date()))
            try locationRecord.set("likeCount", value: 0)
            
            _ = locationRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
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
