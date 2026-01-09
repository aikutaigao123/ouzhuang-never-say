//
//  PatMessage.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//  Copyright © 2024 NeverSayNo. All rights reserved.
//

import Foundation
import LeanCloud

/**
 * 拍一拍消息类型
 * 基于IMMessage实现自定义拍一拍消息
 */
class PatMessage: NSObject {
    
    // MARK: - 消息类型标识
    static let messageType = "pat"
    
    // MARK: - 属性
    var patContent: String
    var fromUserName: String
    var toUserName: String
    var patType: String
    var timestamp: Date
    
    // MARK: - 初始化方法
    
    /**
     * 创建拍一拍消息
     * - Parameters:
     *   - fromUserName: 发送者用户名
     *   - toUserName: 接收者用户名
     *   - patContent: 拍一拍内容
     *   - patType: 拍一拍类型
     */
    init(fromUserName: String, toUserName: String, patContent: String = "拍了拍你", patType: String = "normal") {
        self.fromUserName = fromUserName
        self.toUserName = toUserName
        self.patContent = patContent
        self.patType = patType
        self.timestamp = Date()
        
        super.init()
        
    }
    
    /**
     * 从现有消息创建拍一拍消息
     * - Parameter message: 现有消息
     */
    convenience init(from message: IMMessage) {
        let fromUserName = message.fromClientID ?? "未知用户"
        let toUserName = "未知用户" // 需要从对话中获取
        let patContent = "拍了拍你"
        
        self.init(fromUserName: fromUserName, toUserName: toUserName, patContent: patContent)
        
    }
    
    // MARK: - 消息内容方法
    
    /**
     * 获取显示文本
     */
    func getDisplayText() -> String {
        return "\(fromUserName) \(patContent)"
    }
    
    /**
     * 获取详细描述
     */
    func getDescription() -> String {
        return "拍一拍消息: \(fromUserName) -> \(toUserName), 内容: \(patContent), 类型: \(patType)"
    }
    
    /**
     * 检查是否是有效的拍一拍消息
     */
    func isValidPatMessage() -> Bool {
        return !fromUserName.isEmpty && !toUserName.isEmpty && !patContent.isEmpty
    }
    
    // MARK: - 静态方法
    
    /**
     * 创建默认拍一拍消息
     */
    static func createDefaultPatMessage(fromUserName: String, toUserName: String) -> PatMessage {
        return PatMessage(
            fromUserName: fromUserName,
            toUserName: toUserName,
            patContent: "拍了拍你",
            patType: "normal"
        )
    }
    
    /**
     * 创建特殊拍一拍消息
     */
    static func createSpecialPatMessage(fromUserName: String, toUserName: String, patContent: String) -> PatMessage {
        return PatMessage(
            fromUserName: fromUserName,
            toUserName: toUserName,
            patContent: patContent,
            patType: "special"
        )
    }
    
    /**
     * 从字典创建拍一拍消息
     */
    static func fromDictionary(_ dict: [String: Any]) -> PatMessage? {
        guard let fromUserName = dict["fromUserName"] as? String,
              let toUserName = dict["toUserName"] as? String else {
            return nil
        }
        
        let patContent = dict["patContent"] as? String ?? "拍了拍你"
        let patType = dict["patType"] as? String ?? "normal"
        
        return PatMessage(
            fromUserName: fromUserName,
            toUserName: toUserName,
            patContent: patContent,
            patType: patType
        )
    }
    
    /**
     * 转换为字典
     */
    func toDictionary() -> [String: Any] {
        return [
            "messageType": "pat",
            "fromUserName": fromUserName,
            "toUserName": toUserName,
            "patContent": patContent,
            "patType": patType,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - 拍一拍消息类型枚举
enum PatMessageType: String, CaseIterable {
    case normal = "normal"
    case special = "special"
    case greeting = "greeting"
    case goodbye = "goodbye"
    
    var displayName: String {
        switch self {
        case .normal:
            return "普通拍一拍"
        case .special:
            return "特殊拍一拍"
        case .greeting:
            return "打招呼"
        case .goodbye:
            return "告别"
        }
    }
    
    var defaultContent: String {
        switch self {
        case .normal:
            return "拍了拍你"
        case .special:
            return "特别拍了拍你"
        case .greeting:
            return "拍了拍你，你好！"
        case .goodbye:
            return "拍了拍你，再见！"
        }
    }
}
