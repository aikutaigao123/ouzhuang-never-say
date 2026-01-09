import SwiftUI
import CoreLocation

/// 罗盘详情界面（黑色背景）
struct CompassDetailView: View {
    @ObservedObject var locationManager: LocationManager
    let randomRecord: LocationRecord?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 🎯 修改：背景色改为纯黑色
            Color.black
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // 🎯 移除：顶部关闭按钮已取消
                    
                    // 🎯 修改：将罗盘定位在从顶部算起的三分之一处
                    // 计算位置：屏幕高度的1/3减去罗盘高度的一半
                    let compassHeight: CGFloat = 250 // 罗盘高度
                    let targetTopPosition = geometry.size.height / 3.0 // 目标位置（从顶部算起）
                    let spacerHeight = max(0, targetTopPosition - compassHeight / 2)
                    
                    Spacer()
                        .frame(height: spacerHeight)
                    
                    // 🎯 新增：使用 HStack 确保罗盘水平居中
                    HStack {
                        Spacer()
                        
                        // 罗盘显示（详情界面专用：黑色背景，白色圆圈和文字）
                        ZStack {
                            // 🎯 修改：使用白色圆圈，黑色背景
                            // 外圈
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 250, height: 250)
                            
                            // 内圈
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                .frame(width: 200, height: 200)
                            
                            // 🎯 修改：方向标记（白色文字）
                            ForEach(0..<8, id: \.self) { index in
                                let angle = Double(index) * 45.0
                                let direction = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][index]
                                let color: Color = index == 0 ? .red : .white // 🎯 修改：N保持红色，其他改为白色
                                let headingValue = locationManager.heading?.trueHeading ?? 0
                                
                                VStack {
                                    Text(direction)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(color)
                                    Spacer()
                                }
                                .frame(width: 250, height: 250)
                                .rotationEffect(.degrees(angle - headingValue))
                                .animation(.easeInOut(duration: 0.3), value: headingValue)
                            }
                            
                            // 指针（始终显示）
                            SearchPointerView(
                                locationManager: locationManager,
                                randomRecord: randomRecord,
                                showPointer: .constant(true)
                            )
                        }
                        .frame(width: 250, height: 250)
                        .contentShape(Circle()) // 🎯 新增：设置点击区域为圆形
                        .onTapGesture {
                            // 🎯 修改：点击罗盘退出详情界面
                            dismiss()
                        }
                        
                        Spacer()
                    }
                    
                    // 距离和方向信息（显示手机正前方指向的方向）
                    if let record = randomRecord, let currentLocation = locationManager.location {
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
                        // 🎯 修改：获取手机正前方指向的方向（heading），这个值会实时更新
                        let heading = locationManager.heading?.trueHeading ?? 0
                        
                        VStack(spacing: 12) {
                            // 距离信息（无emoji，字体放大）
                            Text(DistanceUtils.formatDistance(distance))
                                .font(.system(size: 48, weight: .bold)) // 🎯 放大字体
                                .foregroundColor(.green)
                                .lineLimit(1) // 🎯 不可换行
                                .truncationMode(.tail) // 🎯 超出部分截断
                                .minimumScaleFactor(0.5) // 🎯 允许字体缩小以适应屏幕
                            
                            // 🎯 修改：显示手机正前方指向的方向（例如"179° 南"）
                            // 这个方向会随着设备旋转而实时更新
                            Text(BearingUtils.formatDirectionDisplay(heading))
                                .font(.system(size: 32, weight: .medium)) // 🎯 方向字体稍小
                                .foregroundColor(.white) // 🎯 白色文字（黑色背景）
                                .lineLimit(1)
                                .id("direction-\(heading)") // 🎯 添加id以便实时更新
                        }
                        .padding(.top, 72.6) // 🎯 修改：增加与罗盘的距离（改为72.6）
                        .padding(.horizontal, 40)
                        // 🎯 新增：监听朝向变化，实时更新方向显示
                        .onChange(of: locationManager.heading?.trueHeading) { _, _ in
                            // 朝向变化时，视图会自动重新渲染以更新方向显示
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

