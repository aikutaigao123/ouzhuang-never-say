//
//  LeanCloudIMMigrationManager.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  LeanCloud IM 迁移管理器 - 平滑升级到WebSocket
//

import Foundation
import UIKit
import Combine

/**
 * LeanCloud IM 迁移管理器
 * 负责管理 WebSocket IM 连接
 */
class LeanCloudIMMigrationManager: ObservableObject {
    static let shared = LeanCloudIMMigrationManager()
    
    // MARK: - 属性
    private let oldIMTrigger = LeanCloudIMTrigger.shared
    private let newWebSocketIM = LeanCloudWebSocketIM.shared
    private let webSocketService = LeanCloudWebSocketIMService.shared
    
    // 迁移状态
    @Published var migrationStatus: MigrationStatus = .notStarted
    @Published var isWebSocketEnabled = false
    @Published var connectionStats: (old: Bool, new: Bool) = (false, false)
    
    // 配置
    private let config = Configuration.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupMigrationListener()
    }
    
    // MARK: - 公共接口
    
    /**
     * 开始迁移到WebSocket架构
     */
    func startMigration() {
        migrationStatus = .inProgress
        
        // 1. 停止旧的 IM 连接
        stopOldIMConnection()
        
        // 2. 启动新的WebSocket连接
        startWebSocketConnection()
        
        // 3. 验证连接状态
        validateConnection()
    }
    
    /**
     * 断开 WebSocket 连接
     */
    func disconnectWebSocket() {
        migrationStatus = .rollback
        
        // 断开WebSocket连接
        newWebSocketIM.disconnect()
        webSocketService.disconnectService()
        
        // 更新状态
        isWebSocketEnabled = false
        migrationStatus = .completed
    }
    
    /**
     * 检查迁移状态
     */
    func checkMigrationStatus() {
        let oldStats = oldIMTrigger.getConnectionStats()
        let newStats = newWebSocketIM.getConnectionStats()
        
        connectionStats = (old: oldStats.isConnected, new: newStats.isConnected)
        
        if newStats.isConnected {
            migrationStatus = .completed
            isWebSocketEnabled = true
        } else if oldStats.isConnected {
            migrationStatus = .rollback
            isWebSocketEnabled = false
        } else {
            migrationStatus = .failed
        }
    }
    
    /**
     * 获取当前使用的IM服务
     */
    func getCurrentIMService() -> Any {
        if isWebSocketEnabled {
            return webSocketService
        } else {
            return oldIMTrigger
        }
    }
    
    // MARK: - 私有方法
    
    /**
     * 设置迁移监听器
     */
    private func setupMigrationListener() {
        // 监听WebSocket连接状态
        NotificationCenter.default.publisher(for: .imWebSocketConnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWebSocketConnected()
            }
            .store(in: &cancellables)
        
        // 监听WebSocket错误
        NotificationCenter.default.publisher(for: .imWebSocketError)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWebSocketError()
            }
            .store(in: &cancellables)
        
        // 定期检查迁移状态
        Timer.publish(every: 10.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkMigrationStatus()
            }
            .store(in: &cancellables)
    }
    
    /**
     * 停止旧的 IM 连接
     */
    private func stopOldIMConnection() {
        oldIMTrigger.disconnect()
    }
    
    /**
     * 启动WebSocket连接
     */
    private func startWebSocketConnection() {
        
        // 获取当前用户信息
        guard let userId = UserDefaultsManager.getCurrentUserId() else {
            migrationStatus = .failed
            return
        }
        let userName = UserDefaultsManager.getCurrentUserName()
        
        // 🚀 修复：确保在 background QoS 线程上执行，避免线程优先级反转
        let currentQoS = Thread.current.qualityOfService
        if currentQoS == .userInteractive || currentQoS == .userInitiated {
            DispatchQueue.global(qos: .background).async {
                self.newWebSocketIM.initializeIM(userId: userId, userName: userName)
                self.webSocketService.initializeService(userId: userId, userName: userName)
            }
        } else {
            // 初始化WebSocket IM
            newWebSocketIM.initializeIM(userId: userId, userName: userName)
            webSocketService.initializeService(userId: userId, userName: userName)
        }
    }
    
    /**
     * 验证连接状态
     */
    private func validateConnection() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.checkMigrationStatus()
            
            if self.migrationStatus == .completed {
            } else {
                self.disconnectWebSocket()
            }
        }
    }
    
    /**
     * 处理WebSocket连接成功
     */
    private func handleWebSocketConnected() {
        migrationStatus = .completed
        isWebSocketEnabled = true
    }
    
    /**
     * 处理WebSocket错误
     */
    private func handleWebSocketError() {
        migrationStatus = .failed
        // WebSocket 连接失败，断开连接
        disconnectWebSocket()
    }
    
    /**
     * 获取迁移报告
     */
    func getMigrationReport() -> MigrationReport {
        let oldStats = oldIMTrigger.getConnectionStats()
        let newStats = newWebSocketIM.getConnectionStats()
        
        return MigrationReport(
            migrationStatus: migrationStatus,
            isWebSocketEnabled: isWebSocketEnabled,
            oldConnectionStatus: oldStats.isConnected,
            newConnectionStatus: newStats.isConnected,
            oldReconnectAttempts: oldStats.reconnectAttempts,
            newReconnectAttempts: newStats.reconnectAttempts,
            timestamp: Date()
        )
    }
}

// MARK: - 迁移状态枚举

enum MigrationStatus {
    case notStarted
    case inProgress
    case completed
    case failed
    case rollback
}

// MARK: - 迁移报告结构

struct MigrationReport {
    let migrationStatus: MigrationStatus
    let isWebSocketEnabled: Bool
    let oldConnectionStatus: Bool
    let newConnectionStatus: Bool
    let oldReconnectAttempts: Int
    let newReconnectAttempts: Int
    let timestamp: Date
    
    var description: String {
        return """
        迁移状态: \(migrationStatus)
        WebSocket启用: \(isWebSocketEnabled)
        旧连接状态: \(oldConnectionStatus)
        新连接状态: \(newConnectionStatus)
        旧重连次数: \(oldReconnectAttempts)
        新重连次数: \(newReconnectAttempts)
        时间: \(timestamp)
        """
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    static let imMigrationStarted = Notification.Name("imMigrationStarted")
    static let imMigrationCompleted = Notification.Name("imMigrationCompleted")
    static let imMigrationFailed = Notification.Name("imMigrationFailed")
    static let imMigrationRollback = Notification.Name("imMigrationRollback")
}

