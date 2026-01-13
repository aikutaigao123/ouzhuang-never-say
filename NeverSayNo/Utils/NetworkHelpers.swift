import SwiftUI
import Foundation
import Network

struct NetworkHelpers {
    // 检查网络连接状态
    static func isNetworkAvailable() -> Bool {
        let monitor = NWPathMonitor()
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            isConnected = path.status == .satisfied
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()
        
        return isConnected
    }
    
    // 获取网络类型
    static func getNetworkType() -> String {
        let monitor = NWPathMonitor()
        var networkType = "未知"
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            if path.usesInterfaceType(.wifi) {
                networkType = "WiFi"
            } else if path.usesInterfaceType(.cellular) {
                networkType = "蜂窝网络"
            } else if path.usesInterfaceType(.wiredEthernet) {
                networkType = "以太网"
            } else {
                networkType = "其他"
            }
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()
        
        return networkType
    }
    
    // 检查是否为WiFi连接
    static func isWiFiConnected() -> Bool {
        let monitor = NWPathMonitor()
        var isWiFi = false
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            isWiFi = path.usesInterfaceType(.wifi)
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()
        
        return isWiFi
    }
    
    // 检查是否为蜂窝网络连接
    static func isCellularConnected() -> Bool {
        let monitor = NWPathMonitor()
        var isCellular = false
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            isCellular = path.usesInterfaceType(.cellular)
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()
        
        return isCellular
    }
    
    // 获取网络状态描述
    static func getNetworkStatusDescription() -> String {
        if isNetworkAvailable() {
            let type = getNetworkType()
            return "网络连接正常 (\(type))"
        } else {
            return "网络连接不可用"
        }
    }
    
    // 检查网络质量
    static func getNetworkQuality() -> String {
        let monitor = NWPathMonitor()
        var quality = "未知"
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                if path.usesInterfaceType(.wifi) {
                    quality = "优秀"
                } else if path.usesInterfaceType(.cellular) {
                    quality = "良好"
                } else {
                    quality = "一般"
                }
            } else {
                quality = "差"
            }
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        monitor.cancel()
        
        return quality
    }
    
    // 格式化网络速度
    static func formatNetworkSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }
    
    // 检查网络延迟
    static func checkNetworkLatency(completion: @escaping (Double) -> Void) {
        let startTime = Date()
        let url = URL(string: "https://www.apple.com")!
        
        let task = URLSession.shared.dataTask(with: url) { _, _, error in
            let endTime = Date()
            let latency = endTime.timeIntervalSince(startTime)
            
            DispatchQueue.main.async {
                if error != nil {
                    completion(-1) // 网络错误
                } else {
                    completion(latency * 1000) // 转换为毫秒
                }
            }
        }
        
        task.resume()
    }
}
