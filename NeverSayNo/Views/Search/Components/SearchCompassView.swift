//
//  SearchCompassView.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/1/17.
//

import SwiftUI
import CoreLocation

struct SearchCompassView: View {
    @ObservedObject var locationManager: LocationManager
    let randomRecord: LocationRecord?
    @State private var previousSearchPointerAngle: Double = 0
    @State private var showPointer: Bool = false // 🎯 新增：控制指针显示状态
    @State private var showAppIconBackground: Bool = true // 🎯 新增：控制是否显示app图标背景（高手时默认true）
    
    // 🎯 新增：检查当前匹配用户是否在前3名中
    private var isTop3RankingUser: Bool {
        guard let userId = randomRecord?.userId else {
            return false
        }
        let top3UserIds = UserDefaultsManager.getTop3RankingUserIds()
        return top3UserIds.contains(userId)
    }
    
    // 🎯 新增：计算指针是否应该显示
    private var shouldShowPointer: Bool {
        // 如果是高手，根据showAppIconBackground决定：显示app图标时隐藏指针，显示默认轮盘时显示指针
        if isTop3RankingUser {
            return !showAppIconBackground // app图标背景时隐藏指针，默认轮盘时显示指针
        }
        return true
    }
    
    var body: some View {
        ZStack {
            if isTop3RankingUser {
                // 🎯 高手匹配卡片：根据点击状态切换背景
                if showAppIconBackground {
                    // 显示app图标背景
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250, height: 250)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.purple.opacity(0.6), lineWidth: 3)
                                .frame(width: 250, height: 250)
                        )
                } else {
                    // 显示默认轮盘背景
                    Circle()
                        .stroke(Color.gray, lineWidth: 3)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        .frame(width: 200, height: 200)
                }
            } else {
                // 默认：外圈
                Circle()
                    .stroke(Color.gray, lineWidth: 3)
                    .frame(width: 250, height: 250)
                
                // 内圈
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: 200, height: 200)
            }
            
            // 方向标记 - 根据设备方向旋转
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * 45.0
                let direction = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][index]
                let color: Color = index == 0 ? .red : .black
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
            
            // 🎯 新增：点击手势 - 高手匹配卡片时切换背景和指针显示
            Color.clear
                .frame(width: 250, height: 250)
                .contentShape(Circle())
                .onTapGesture {
                    if isTop3RankingUser {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAppIconBackground.toggle()
                        }
                    }
                }
            
            // 指针显示 - 指向当前匹配用户
            if shouldShowPointer {
                if let currentLocation = locationManager.location {
                    if let record = randomRecord {
                        // ⚖️ 坐标系转换：LocationRecord中存储的是GCJ-02坐标，需要转回WGS-84才能与当前位置（WGS-84）正确计算方位角
                        let (wgsLat, wgsLon) = CoordinateConverter.gcj02ToWgs84(
                            latitude: record.latitude,
                            longitude: record.longitude
                        )
                        // 有匹配用户时，指针指向匹配用户的方向
                        let bearing = BearingUtils.calculateBearing(from: currentLocation, to: wgsLat, targetLongitude: wgsLon)
                        let headingValue = locationManager.heading?.trueHeading ?? 0
                        
                        // 计算最短路径的角度差，避免指针旋转一圈
                        let rawAngle = calculateShortestAngle(from: headingValue, to: bearing)
                        
                        // 使用智能角度管理，避免突然的大角度跳跃
                        let displayPointerAngle = calculateSmartSearchPointerAngle(rawAngle: rawAngle)
                        
                        Image(systemName: "location.north.fill")
                            .imageScale(.large)
                            .foregroundStyle(.blue) // 🎯 指针永远是蓝色
                            .font(.system(size: 50))
                            .rotationEffect(.degrees(displayPointerAngle))
                            .animation(
                                abs(displayPointerAngle) <= 10 ? 
                                    .easeInOut(duration: 0.3) :  // 小角度快速动画
                                    .spring(response: 0.6, dampingFraction: 0.8),  // 大角度弹性动画
                                value: displayPointerAngle
                            )
                            .shadow(radius: 2)
                    } else {
                        // 没有匹配用户时，指针指向正北
                        let headingValue = locationManager.heading?.trueHeading ?? 0
                        
                        Image(systemName: "location.north.fill")
                            .imageScale(.large)
                            .foregroundStyle(.blue) // 🎯 指针永远是蓝色
                            .font(.system(size: 50))
                            .rotationEffect(.degrees(-headingValue))
                            .animation(.easeInOut(duration: 0.3), value: headingValue)
                            .shadow(radius: 2)
                    }
                } else {
                    // 没有位置信息时，指针也根据设备方向转动
                    let headingValue = locationManager.heading?.trueHeading ?? 0
                    
                    Image(systemName: "location.north.fill")
                        .imageScale(.large)
                        .foregroundStyle(.blue) // 🎯 指针永远是蓝色
                        .font(.system(size: 50))
                        .rotationEffect(.degrees(-headingValue))
                        .animation(.easeInOut(duration: 0.3), value: headingValue)
                        .shadow(radius: 2)
                }
            }
        }
        .onChange(of: randomRecord?.userId) { oldValue, newValue in
            // 🎯 新增：当匹配用户变化时，如果是高手，重置为app图标背景
            if isTop3RankingUser {
                showAppIconBackground = true
            }
        }
        .onAppear {
            // 初始化：高手默认显示app图标背景
            if isTop3RankingUser {
                showAppIconBackground = true
            }
        }
    }
    
    // MARK: - 角度计算工具函数
    
    /// 计算最短角度差，避免指针旋转一圈
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
    
    /// 智能角度管理，避免突然的大角度跳跃
    private func calculateSmartSearchPointerAngle(rawAngle: Double) -> Double {
        // 计算与前一个角度的差值
        let angleChange = rawAngle - previousSearchPointerAngle
        
        // 如果角度变化很大（超过90度），可能是由于边界跳跃导致的
        if abs(angleChange) > 90 {
            // 选择更平滑的路径
            let alternativeAngle = previousSearchPointerAngle + (angleChange > 0 ? -360 : 360) + angleChange
            if abs(alternativeAngle - previousSearchPointerAngle) < abs(angleChange) {
                // 更新状态
                DispatchQueue.main.async {
                    self.previousSearchPointerAngle = alternativeAngle
                }
                return alternativeAngle
            }
        }
        
        // 更新状态
        DispatchQueue.main.async {
            self.previousSearchPointerAngle = rawAngle
        }
        
        return rawAngle
    }
}

#Preview {
    SearchCompassView(
        locationManager: LocationManager(),
        randomRecord: nil
    )
}
