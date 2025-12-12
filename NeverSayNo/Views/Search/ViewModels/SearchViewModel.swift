import SwiftUI
import CoreLocation
import Foundation

class SearchViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isLoadingRandomRecord = false
    @Published var randomRecord: LocationRecord?
    @Published var resultMessage = ""
    @Published var showAlert = false
    
    private let locationManager: LocationManager
    private let userManager: UserManager
    private let diamondManager: DiamondManager
    private let locationService: SearchLocationService
    
    init(locationManager: LocationManager, userManager: UserManager, diamondManager: DiamondManager) {
        self.locationManager = locationManager
        self.userManager = userManager
        self.diamondManager = diamondManager
        self.locationService = SearchLocationService(locationManager: locationManager, userManager: userManager, diamondManager: diamondManager)
    }
    
    // 发送位置到服务器
    func sendLocationToServer() {
        guard diamondManager.checkDiamondsWithDebug(2) else {
            // 触发充值界面
            return
        }
        
        isLoading = true
        resultMessage = ""
        
        // 首先请求更新位置信息
        locationManager.requestLocation()
        
        // 等待位置更新完成后再发送
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.locationService.performLocationSend { success, message in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if success {
                        self.fetchRandomRecord()
                    } else {
                        self.resultMessage = message
                        self.showAlert = true
                    }
                }
            }
        }
    }
    
    // 获取随机记录
    func fetchRandomRecord() {
        isLoadingRandomRecord = true
        randomRecord = nil
        
        // 先获取所有记录以确定总数
        LeanCloudService.shared.fetchLocations { records, error in
            DispatchQueue.main.async {
                if let _ = error {
                    self.isLoadingRandomRecord = false
                    return
                }
                
                _ = records?.count ?? 0
                
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
                        } else if let record = record {
                            // 🎯 修改：成功匹配到用户，先同步服务器数据再扣除钻石
                            self.diamondManager.spendDiamonds(2) { success in
                                if success {
                                    // 钻石扣除成功，设置匹配结果
                                    self.randomRecord = record
                                } else {
                                    // 钻石扣除失败，不设置匹配结果
                                }
                            }
                            
                            // 匹配成功后刷新头像缓存
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                // 刷新头像缓存
                            }
                            
                            // 静默执行位置记录清理
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self.silentCleanLocationRecords()
                            }
                        } else {
                            // 没有匹配到用户，不扣除钻石
                        }
                    }
                }
            }
        }
    }
    
    // 静默清理位置记录
    private func silentCleanLocationRecords() {
        
        // 获取当前用户ID
        guard let currentUserId = userManager.currentUser?.id else {
            return
        }
        
        
        // 获取所有位置记录
        LeanCloudService.shared.fetchAllLocationRecords { allRecords, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
            
                guard let records = allRecords, !records.isEmpty else {
                    return
                }
                
                
                // 只过滤当前用户的记录
                let currentUserRecords = records.filter { $0.userId == currentUserId }
                
                if currentUserRecords.isEmpty {
                    return
                }
                
                
                // 如果当前用户只有一条记录，无需清理
                if currentUserRecords.count == 1 {
                    return
                }
                
                // 按时间戳排序，保留最新的
                let sortedRecords = currentUserRecords.sorted { record1, record2 in
                    let date1 = ISO8601DateFormatter().date(from: record1.timestamp) ?? Date.distantPast
                    let date2 = ISO8601DateFormatter().date(from: record2.timestamp) ?? Date.distantPast
                    return date1 > date2
                }
                
                // 保留最新的记录
                let latestRecord = sortedRecords.first!
                let _ = [latestRecord]
                
                // 删除其他重复记录
                let recordsToDelete = Array(sortedRecords.dropFirst())
                
                
                // 执行删除操作
                if !recordsToDelete.isEmpty {
                    
                    let recordIds = recordsToDelete.map { $0.objectId }
                    LeanCloudService.shared.deleteLocationRecords(recordIds: recordIds) { success, error in
                        DispatchQueue.main.async {
                            if success {
                            } else {
                            }
                        }
                    }
                } else {
                }
            }
        }
    }
}