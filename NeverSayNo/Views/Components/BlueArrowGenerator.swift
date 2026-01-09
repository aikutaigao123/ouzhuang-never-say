//
//  BlueArrowGenerator.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

// MARK: - 蓝色箭头生成器 - 基于Python脚本设计
struct BlueArrowGenerator: View {
    let targetAngle: Double = 70 // 70度角度，与Python脚本一致
    let height: Double = 1.8
    let length: Double // 动态计算
    let offset: Double // 动态计算
    let sharpLength: Double // 增加锐度
    let sharpHeight: Double // 增加高度
    
    init() {
        self.length = height / 3
        self.offset = height / tan(targetAngle * .pi / 180)
        self.sharpLength = length * 2.5 // 增加箭头长度
        self.sharpHeight = height * 1.2 // 稍微增加高度
    }
    
    var body: some View {
        ZStack {
            // 上箭头
            BlueArrowShape(
                targetAngle: targetAngle,
                height: sharpHeight,
                length: sharpLength,
                offset: offset,
                isTop: true
            )
            .fill(Color.blue)
            .frame(width: 120, height: 60)
            
            // 下箭头
            BlueArrowShape(
                targetAngle: targetAngle,
                height: sharpHeight,
                length: sharpLength,
                offset: offset,
                isTop: false
            )
            .fill(Color.blue)
            .frame(width: 120, height: 60)
        }
    }
}

// MARK: - 蓝色箭头形状
struct BlueArrowShape: Shape {
    let targetAngle: Double
    let height: Double
    let length: Double
    let offset: Double
    let isTop: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let centerX = rect.width / 2
        let centerY = rect.height / 2
        
        // 根据Python脚本的点集生成路径
        let points = generateArrowPoints(centerX: centerX, centerY: centerY)
        
        // 构建路径
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        path.closeSubpath()
        
        return path
    }
    
    private func generateArrowPoints(centerX: CGFloat, centerY: CGFloat) -> [CGPoint] {
        // 基于Python脚本的精确点集计算
        let basePoints: [(Double, Double)] = [
            (0, 0),
            (length, 0),
            (length + offset, isTop ? height : -height),
            (offset, isTop ? height : -height),
            (0, 0)
        ]
        
        // 旋转90度，让箭头尖头向上指向目标方向
        let rotatedPoints = basePoints.map { (x, y) in
            rotatePoint(x: x, y: y, angle: 90)
        }
        
        // 转换到视图坐标系，使用合适的缩放因子
        return rotatedPoints.map { (x, y) in
            CGPoint(
                x: centerX + CGFloat(x * 50), // 调整缩放因子以匹配Python输出
                y: centerY + CGFloat(y * 50)
            )
        }
    }
    
    private func rotatePoint(x: Double, y: Double, angle: Double) -> (Double, Double) {
        let radians = angle * .pi / 180
        let cos_a = cos(radians)
        let sin_a = sin(radians)
        
        return (
            x * cos_a - y * sin_a,
            x * sin_a + y * cos_a
        )
    }
}

// MARK: - 预览
struct BlueArrowGenerator_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.white
            BlueArrowGenerator()
        }
        .frame(width: 200, height: 200)
    }
}
