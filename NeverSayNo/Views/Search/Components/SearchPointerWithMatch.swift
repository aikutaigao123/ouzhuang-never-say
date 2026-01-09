import SwiftUI
import CoreLocation

struct SearchPointerWithMatch: View {
    let currentLocation: CLLocation
    let record: LocationRecord
    let headingValue: Double
    @State private var previousPointerAngle: Double = 0
    
    var body: some View {
        // ⚖️ 坐标系转换：LocationRecord中存储的是GCJ-02坐标，需要转回WGS-84才能与当前位置（WGS-84）正确计算方位角
        let (wgsLat, wgsLon) = CoordinateConverter.gcj02ToWgs84(
            latitude: record.latitude,
            longitude: record.longitude
        )
        let bearing = BearingUtils.calculateBearing(
            from: currentLocation,
            to: wgsLat,
            targetLongitude: wgsLon
        )
        
        // 计算最短路径的角度差，避免指针旋转一圈
        let rawAngle = calculateShortestAngle(from: headingValue, to: bearing)
        
        // 使用智能角度管理，避免突然的大角度跳跃
        let displayPointerAngle = calculateSmartPointerAngle(rawAngle: rawAngle)
        
        SearchPointerImage()
            .rotationEffect(.degrees(displayPointerAngle))
            .animation(
                abs(displayPointerAngle) <= 10 ? 
                    .easeInOut(duration: 0.3) :  // 小角度快速动画
                    .spring(response: 0.6, dampingFraction: 0.8),  // 大角度弹性动画
                value: displayPointerAngle
            )
    }
    
    // 计算最短路径角度差
    private func calculateShortestAngle(from: Double, to: Double) -> Double {
        var angleDifference = to - from
        
        // 标准化到 [-180, 180] 范围
        while angleDifference > 180 {
            angleDifference -= 360
        }
        while angleDifference < -180 {
            angleDifference += 360
        }
        
        return angleDifference
    }
    
    // 智能角度管理 - 避免突然的大角度跳跃
    private func calculateSmartPointerAngle(rawAngle: Double) -> Double {
        // 计算与前一个角度的差值
        let angleChange = rawAngle - previousPointerAngle
        
        // 如果角度变化很大（超过90度），可能是由于边界跳跃导致的
        if abs(angleChange) > 90 {
            // 选择更平滑的路径
            let alternativeAngle = previousPointerAngle + (angleChange > 0 ? -360 : 360) + angleChange
            if abs(alternativeAngle - previousPointerAngle) < abs(angleChange) {
                // 更新状态
                DispatchQueue.main.async {
                    self.previousPointerAngle = alternativeAngle
                }
                return alternativeAngle
            }
        }
        
        // 更新状态
        DispatchQueue.main.async {
            self.previousPointerAngle = rawAngle
        }
        
        return rawAngle
    }
}
