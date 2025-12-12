//
//  AnimatedGradientText.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import SwiftUI

// 彩色文字视图修饰符（静态渐变）
struct AnimatedGradientTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        .red,
                        .orange,
                        .yellow,
                        .green,
                        .blue,
                        .indigo,
                        .purple,
                        .pink
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// 扩展方法，方便使用
extension View {
    func animatedGradientText() -> some View {
        self.modifier(AnimatedGradientTextModifier())
    }
}

