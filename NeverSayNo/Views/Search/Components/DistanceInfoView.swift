import SwiftUI
import CoreLocation

struct DistanceInfoView: View {
    let record: LocationRecord
    @ObservedObject var locationManager: LocationManager
    let scale: CGFloat
    @State private var previousPointerAngle: Double = 0 // 🎯 新增：跟踪前一个角度，用于平滑旋转
    
    var body: some View {
        if let currentLocation = locationManager.location {
            // ⚖️ 坐标系转换：LocationRecord中存储的是GCJ-02坐标，需要转回WGS-84才能与当前位置（WGS-84）正确计算距离
            let (wgsLat, wgsLon) = CoordinateConverter.gcj02ToWgs84(
                latitude: record.latitude,
                longitude: record.longitude
            )
            let distance = DistanceUtils.calculateDistance(
                from: currentLocation,
                to: wgsLat,
                targetLongitude: wgsLon
            )
            
            // 🎯 新增：计算方位角和旋转角度
            let bearing = BearingUtils.calculateBearing(
                from: currentLocation,
                to: wgsLat,
                targetLongitude: wgsLon
            )
            let headingValue = locationManager.heading?.trueHeading ?? 0
            
            // 计算最短路径的角度差，避免指针旋转一圈
            let rawAngle = calculateShortestAngle(from: headingValue, to: bearing)
            
            // 使用智能角度管理，避免突然的大角度跳跃
            let displayPointerAngle = calculateSmartPointerAngle(rawAngle: rawAngle)
            
            VStack(spacing: getVerticalSpacing()) {
                Image(systemName: "location.north.fill") // 🎯 修改：使用有方向性的图标，与按钮上方指针一致
                    .foregroundColor(.green)
                    .font(.system(size: 24))
                    .rotationEffect(.degrees(displayPointerAngle)) // 🎯 新增：旋转图标指向匹配用户方向
                    .animation(
                        abs(displayPointerAngle) <= 10 ? 
                            .easeInOut(duration: 0.3) :  // 小角度快速动画
                            .spring(response: 0.6, dampingFraction: 0.8),  // 大角度弹性动画
                        value: displayPointerAngle
                    )
                Text(DistanceUtils.formatDistance(distance))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func getVerticalSpacing() -> CGFloat {
        if scale < 0.6 {
            if scale < 0.3 { return 0 }
            if scale < 0.4 { return 1 }
            if scale < 0.5 { return 2 }
            return 4
        }
        return 6
    }
    
    // 🎯 新增：计算最短路径角度差
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
    
    // 🎯 新增：智能角度管理 - 避免突然的大角度跳跃
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
