import Foundation
import CoreLocation

// 随机匹配历史记录结构体
struct RandomMatchHistory: Codable, Identifiable {
    let id: UUID
    let record: LocationRecord
    let recordNumber: Int
    let matchTime: Date
    let currentLatitude: Double?
    let currentLongitude: Double?
    
    init(record: LocationRecord, recordNumber: Int, currentLocation: CLLocationCoordinate2D?) {
        self.id = UUID()
        self.record = record
        self.recordNumber = recordNumber
        self.matchTime = Date()
        self.currentLatitude = currentLocation?.latitude
        self.currentLongitude = currentLocation?.longitude
    }
    
    var currentLocation: CLLocationCoordinate2D? {
        guard let lat = currentLatitude, let lon = currentLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // 动态计算当前距离（基于用户当前位置）
    func calculateCurrentDistance(from userLocation: CLLocation?) -> Double? {
        guard let userLocation = userLocation else { return nil }
        // ⚖️ 坐标系转换：LocationRecord中存储的是GCJ-02坐标，需要转回WGS-84才能与当前位置（WGS-84）正确计算距离
        let (wgsLat, wgsLon) = CoordinateConverter.gcj02ToWgs84(
            latitude: record.latitude,
            longitude: record.longitude
        )
        return DistanceUtils.calculateDistance(
            from: userLocation,
            to: wgsLat,
            targetLongitude: wgsLon
        )
    }
    
    // 获取匹配时的距离（基于历史位置）
    func getMatchTimeDistance() -> Double? {
        guard let currentLocation = currentLocation else { return nil }
        // ⚖️ 坐标系转换：LocationRecord中存储的是GCJ-02坐标，需要转回WGS-84才能与历史位置（WGS-84）正确计算距离
        let (wgsLat, wgsLon) = CoordinateConverter.gcj02ToWgs84(
            latitude: record.latitude,
            longitude: record.longitude
        )
        return DistanceUtils.calculateDistance(
            from: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude),
            to: wgsLat,
            targetLongitude: wgsLon
        )
    }
}
