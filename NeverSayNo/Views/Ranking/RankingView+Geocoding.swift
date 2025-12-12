import SwiftUI
import CoreLocation

// MARK: - RankingView Geocoding Extension
extension RankingView {
    
    // 地址解析方法
    func geocodeAddress() {
        guard !editableAddress.isEmpty else {
            return
        }
        
        isGeocoding = true
        
        AddressGeocodingService.shared.geocodeAddress(editableAddress) { result in
            DispatchQueue.main.async {
                isGeocoding = false
                
                switch result {
                case .success(let coordinates):
                    // 检查坐标是否有效
                    guard !coordinates.latitude.isNaN && !coordinates.longitude.isNaN else {
                        geocodingError = "坐标解析失败"
                        return
                    }
                    
                    // 保存解析出的坐标
                    geocodedLatitude = coordinates.latitude
                    geocodedLongitude = coordinates.longitude
                    geocodingError = nil // 清除错误信息
                    
                    // 自动更新可编辑的经纬度
                    editableLatitude = String(format: "%.6f", coordinates.latitude)
                    editableLongitude = String(format: "%.6f", coordinates.longitude)
                    
                    // 触发反向地理编码，更新显示的地址
                    self.reverseGeocodeLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
                    
                case .failure:
                    // 解析失败时，清除之前解析的坐标
                    geocodedLatitude = nil
                    geocodedLongitude = nil
                    geocodingError = "解析失败"
                    break
                }
            }
        }
    }
    
    // 获取当前位置
    func getCurrentLocation() {
        guard !isGettingCurrentLocation else {
            return
        }
        
        isGettingCurrentLocation = true
        
        // 请求位置更新
        locationManager.requestLocation()
        
        // 监听位置更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isGettingCurrentLocation = false
            
                if let location = self.locationManager.location {
                    // 获取当前位置成功
                    let wgsLat = location.coordinate.latitude
                    let wgsLon = location.coordinate.longitude
                    
                    // ⚖️ 法律合规：保存原始 WGS-84 坐标（仅用于内部处理）
                    // 注意：这些原始坐标不会直接上传，上传时会转换为 GCJ-02
                    self.rawLatitude = wgsLat
                    self.rawLongitude = wgsLon
                    
                    // ⚖️ 法律合规：将 WGS-84 坐标转换为 GCJ-02 坐标
                    // 根据《中华人民共和国测绘法》要求，UI 显示和数据上传必须使用 GCJ-02 坐标系
                    let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                        latitude: wgsLat,
                        longitude: wgsLon
                    )
                    
                    // ⚖️ 法律合规：UI 显示使用 GCJ-02 坐标
                    self.editableLatitude = String(format: "%.6f", gcjLat)
                    self.editableLongitude = String(format: "%.6f", gcjLon)
                    
                    // 清空地址输入框
                    self.editableAddress = ""
                    
                    // 清除之前解析的地址坐标，使用当前位置
                    self.geocodedLatitude = nil
                    self.geocodedLongitude = nil
                    
                    // 反向地理编码当前位置（使用GCJ-02坐标）
                    self.reverseGeocodeLocation(latitude: gcjLat, longitude: gcjLon)
                }
        }
    }
    
    // 触发反向地理编码（带去抖动）
    func triggerReverseGeocode() {
        // 取消之前的任务
        reverseGeocodeTask?.cancel()
        
        // 捕获当前的经纬度值
        let currentLatitude = editableLatitude
        let currentLongitude = editableLongitude
        
        // 创建新的延迟任务
        let task = DispatchWorkItem {
            // 验证经纬度格式
            guard let latitude = Double(currentLatitude),
                  let longitude = Double(currentLongitude) else {
                return
            }
            
            // 检查坐标是否有效
            guard !latitude.isNaN && !longitude.isNaN && 
                  !latitude.isInfinite && !longitude.isInfinite &&
                  latitude >= -90 && latitude <= 90 &&
                  longitude >= -180 && longitude <= 180 else {
                return
            }
            
            self.reverseGeocodeLocation(latitude: latitude, longitude: longitude)
        }
        
        reverseGeocodeTask = task
        
        // 延迟1秒执行（去抖动）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
    }
}

