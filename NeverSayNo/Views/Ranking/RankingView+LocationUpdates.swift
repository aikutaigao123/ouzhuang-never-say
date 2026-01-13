import SwiftUI
import CoreLocation

// MARK: - RankingView Location Updates Extension
extension RankingView {
    
    // 启动位置更新定时器（每2秒刷新一次）
    func startLocationUpdateTimer() {
        // 先停止现有的定时器
        stopLocationUpdateTimer()
        
        // 创建新的定时器
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateLocationData()
        }
    }
    
    // 更新位置数据（经纬度、精度、反向地理编码地址）
    func updateLocationData() {
        // 主动请求新的位置更新
        locationManager.requestLocation()
        
        // 延迟1秒等待位置更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let location = self.locationManager.location else {
                return
            }
            
            // 获取原始GPS坐标（WGS-84）
            let wgsLat = location.coordinate.latitude
            let wgsLon = location.coordinate.longitude
            
            // 转换为GCJ-02坐标（用于显示）
            let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                latitude: wgsLat,
                longitude: wgsLon
            )
            
            // 只有在用户没有手动编辑经纬度的情况下才自动更新
            // 判断依据：当前editableLatitude/editableLongitude是否与上次的GCJ-02坐标一致
            if self.uploadLocation != nil,
               let lastRawLat = self.rawLatitude,
               let lastRawLon = self.rawLongitude {
                
                // 计算上次的GCJ-02坐标
                let (lastGcjLat, lastGcjLon) = CoordinateConverter.wgs84ToGcj02(
                    latitude: lastRawLat,
                    longitude: lastRawLon
                )
                let lastDisplayLat = String(format: "%.6f", lastGcjLat)
                let lastDisplayLon = String(format: "%.6f", lastGcjLon)
                
                // 如果用户没有修改过经纬度，则自动更新
                if self.editableLatitude == lastDisplayLat && self.editableLongitude == lastDisplayLon {
                    
                    // 更新原始坐标
                    self.rawLatitude = wgsLat
                    self.rawLongitude = wgsLon
                    
                    // 更新显示坐标（GCJ-02）
                    self.editableLatitude = String(format: "%.6f", gcjLat)
                    self.editableLongitude = String(format: "%.6f", gcjLon)
                    
                    // 更新uploadLocation
                    self.uploadLocation = location
                    
                    // 更新uploadData中的经纬度和精度（使用GCJ-02坐标）
                    self.uploadData["latitude"] = gcjLat
                    self.uploadData["longitude"] = gcjLon
                    self.uploadData["accuracy"] = location.horizontalAccuracy
                    
                    // 反向地理编码新位置（使用GCJ-02坐标）
                    self.reverseGeocodeLocation(latitude: gcjLat, longitude: gcjLon)
                }
            }
        }
    }
}

