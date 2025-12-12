import SwiftUI
import Foundation

struct NavigationHelpers {
    // 安全导航到目标页面
    static func safeNavigate(
        to destination: String,
        path: Binding<[String]>,
        isNavigating: Binding<Bool>,
        navigationLock: NSLock
    ) {
        
        navigationLock.lock()
        defer { navigationLock.unlock() }
        
        guard !isNavigating.wrappedValue else {
            return 
        }
        isNavigating.wrappedValue = true
        
        // 使用同步更新，避免异步导致的时序问题
        
        // 确保路径类型一致性
        if path.wrappedValue.isEmpty {
            path.wrappedValue.append(destination)
        } else {
            // 如果路径包含非字符串类型，重置路径
            path.wrappedValue = [destination]
        }
        
        
        // 延迟重置导航标志，但使用更短的时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isNavigating.wrappedValue = false
        }
        
    }
    
    // 安全清空导航路径
    static func safeClearPath(
        path: Binding<[String]>,
        isNavigating: Binding<Bool>,
        navigationLock: NSLock
    ) {
        
        navigationLock.lock()
        defer { navigationLock.unlock() }
        
        guard !isNavigating.wrappedValue else { 
            return 
        }
        isNavigating.wrappedValue = true
        
        // 使用同步清理，避免异步导致的时序问题
        path.wrappedValue = []
        
        // 延迟重置导航标志
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isNavigating.wrappedValue = false
        }
        
    }
}

