import SwiftUI
import CoreLocation

// 统一的随机记录获取服务
class SearchRandomRecordService: ObservableObject {
    @Published var isLoadingRandomRecord = false
    @Published var randomRecord: LocationRecord?
    @Published var randomRecordNumber = 0
    
    private let locationManager: LocationManager
    private let userManager: UserManager
    private let diamondManager: DiamondManager
    
    init(locationManager: LocationManager, userManager: UserManager, diamondManager: DiamondManager) {
        self.locationManager = locationManager
        self.userManager = userManager
        self.diamondManager = diamondManager
    }
    
    // 基础版本 - 用于 SearchViewModel
    func fetchRandomRecord(completion: @escaping (LocationRecord?) -> Void) {
        isLoadingRandomRecord = true
        randomRecord = nil
        
        // 先获取所有记录以确定总数
        LeanCloudService.shared.fetchLocations { records, error in
            DispatchQueue.main.async {
                if let _ = error {
                    self.isLoadingRandomRecord = false
                    completion(nil)
                    return
                }
                
                let _ = records?.count ?? 0
                
                // 使用LeanCloud服务获取随机位置记录
                let currentLocation = self.locationManager.location?.coordinate
                let currentUserId = self.userManager.currentUser?.id
                
                LeanCloudService.shared.fetchRandomLocation(
                    currentLocation: currentLocation, 
                    currentUserId: currentUserId, 
                    excludeHistory: []
                ) { record, error in
                    DispatchQueue.main.async {
                        self.isLoadingRandomRecord = false
                        
                        if let _ = error {
                            // 匹配失败，不扣除钻石
                            completion(nil)
                        } else if let record = record {
                            // 🎯 修改：成功匹配到用户，先同步服务器数据再扣除钻石
                            self.diamondManager.spendDiamonds(2) { success in
                                if success {
                                    // 钻石扣除成功，设置匹配结果
                                    self.randomRecord = record
                                    completion(record)
                                } else {
                                    // 钻石扣除失败，不设置匹配结果
                                    completion(nil)
                                }
                            }
                            
                            // 匹配成功后刷新头像缓存
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                // 刷新头像缓存
                            }
                        } else {
                            // 没有匹配到用户，不扣除钻石
                            completion(nil)
                        }
                    }
                }
            }
        }
    }
    
    // 增强版本 - 用于 ContentView
    func fetchRandomRecordWithHistory(
        randomMatchHistory: [RandomMatchHistory],
        blacklistedUserIds: Set<String>,
        pendingDeletionUserIds: Set<String>,
        onRecordFetched: @escaping (LocationRecord, Int) -> Void,
        onAvatarRefresh: @escaping () -> Void
    ) {
        isLoadingRandomRecord = true
        randomRecord = nil
        randomRecordNumber = 0
        
        // 先获取所有记录以确定总数
        LeanCloudService.shared.fetchLocations { records, error in
            let totalRecords = records?.count ?? 0
            DispatchQueue.main.async {
                if let _ = error {
                    self.isLoadingRandomRecord = false
                    return
                }
                
                // 使用LeanCloud服务获取随机位置记录
                let currentLocation = self.locationManager.location?.coordinate
                let currentUserId = self.userManager.currentUser?.id
                
                // 传递完整的历史记录用于336小时过滤
                LeanCloudService.shared.fetchRandomLocation(
                    currentLocation: currentLocation, 
                    currentUserId: currentUserId, 
                    excludeHistory: randomMatchHistory
                ) { record, error in
                    DispatchQueue.main.async {
                        self.isLoadingRandomRecord = false
                        
                        if let _ = error {
                            // 匹配失败，不扣除钻石
                        } else if let record = record {
                            // 🎯 修改：成功匹配到用户，先同步服务器数据再扣除钻石
                            self.diamondManager.spendDiamonds(2) { success in
                                if success {
                                    // 钻石扣除成功，设置匹配结果
                                    self.randomRecord = record
                                    // 为随机记录分配一个序号（1到总数之间）
                                    self.randomRecordNumber = Int.random(in: 1...max(1, totalRecords))
                                } else {
                                    // 钻石扣除失败，不设置匹配结果
                                }
                            }
                            
                            // 匹配成功后刷新头像缓存
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onAvatarRefresh()
                            }
                            
                            onRecordFetched(record, self.randomRecordNumber)
                        } else {
                            // 没有匹配到用户，不扣除钻石
                        }
                    }
                }
            }
        }
    }
}

