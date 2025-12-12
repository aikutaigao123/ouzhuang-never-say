import Foundation

/// 钻石余额模型（包含版本信息用于冲突检测）
struct DiamondBalance: Codable {
    let amount: Int              // 钻石数量
    let version: Int             // 版本号（用于冲突检测）
    let lastUpdateTime: Date     // 最后更新时间
    let deviceId: String         // 最后更新的设备ID
    var isDirty: Bool           // 是否有未同步的变更
    
    /// 创建一个干净的余额（已同步）
    static func clean(amount: Int, version: Int, deviceId: String) -> DiamondBalance {
        return DiamondBalance(
            amount: amount,
            version: version,
            lastUpdateTime: Date(),
            deviceId: deviceId,
            isDirty: false
        )
    }
    
    /// 创建一个脏的余额（未同步）
    static func dirty(amount: Int, version: Int, deviceId: String) -> DiamondBalance {
        return DiamondBalance(
            amount: amount,
            version: version,
            lastUpdateTime: Date(),
            deviceId: deviceId,
            isDirty: true
        )
    }
    
    /// 增加版本号并标记为脏
    func incrementVersion(newAmount: Int) -> DiamondBalance {
        return DiamondBalance(
            amount: newAmount,
            version: self.version + 1,
            lastUpdateTime: Date(),
            deviceId: self.deviceId,
            isDirty: true
        )
    }
    
    /// 更新为服务器返回的值（清除脏标记）
    func updateFromServer(amount: Int, version: Int, deviceId: String) -> DiamondBalance {
        return DiamondBalance(
            amount: amount,
            version: version,
            lastUpdateTime: Date(),
            deviceId: deviceId,
            isDirty: false
        )
    }
}

/// 钻石操作类型
enum DiamondOperation: Codable {
    case add(amount: Int, source: OperationSource)
    case spend(amount: Int, reason: String)
    
    enum OperationSource: String, Codable {
        case iap              // IAP购买
        case admin            // 管理员操作
        case system           // 系统奖励
        case restore          // 恢复购买
    }
    
    var amount: Int {
        switch self {
        case .add(let amount, _):
            return amount
        case .spend(let amount, _):
            return -amount
        }
    }
}

/// 待同步的操作
struct PendingOperation: Codable, Identifiable {
    let id: UUID
    let operation: DiamondOperation
    let timestamp: Date
    let expectedVersion: Int  // 期望的版本号（乐观锁）
    var retryCount: Int
    
    init(operation: DiamondOperation, expectedVersion: Int) {
        self.id = UUID()
        self.operation = operation
        self.timestamp = Date()
        self.expectedVersion = expectedVersion
        self.retryCount = 0
    }
}

/// 钻石相关错误
enum DiamondError: LocalizedError {
    case insufficientBalance(current: Int, required: Int)
    case versionConflict(localVersion: Int, serverVersion: Int)
    case networkError(underlying: Error)
    case serverError(message: String)
    case invalidUser
    case operationFailed
    
    var errorDescription: String? {
        switch self {
        case .insufficientBalance(let current, let required):
            return "钻石余额不足：当前 \(current)，需要 \(required)"
        case .versionConflict(let local, let server):
            return "版本冲突：本地版本 \(local)，服务器版本 \(server)"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .invalidUser:
            return "用户信息无效"
        case .operationFailed:
            return "操作失败"
        }
    }
}

