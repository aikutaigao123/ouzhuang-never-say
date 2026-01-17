import SwiftUI

struct InfoToast: View {
    let isVisible: Bool
    let message: String
    var title: String? = nil
    var onDismiss: (() -> Void)? = nil
    var onAgree: (() -> Void)? = nil
    var onDisagree: (() -> Void)? = nil
    var agreeButtonText: String? = nil // 🎯 新增：自定义"同意"按钮文本
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // 标题区域（固定）
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                    
                    if title != nil {
                        Text(title!)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // 内容区域（可滚动）
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if title != nil {
                            Text(message)
                                .font(.subheadline)
                                .fontWeight(.regular)
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 26) // 与图标对齐
                                .padding(.trailing, 20)
                        } else {
                            Text(message)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 300) // 最大高度300，超出可滚动
                
                // 按钮区域（固定）
                if onAgree != nil || onDisagree != nil {
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        // 🎯 版本更新通知：只显示一个"更新"按钮，不显示"不同意"按钮
                        if let onAgree = onAgree, onDisagree == nil {
                            // 只有一个按钮时，按钮占满宽度
                            Button(action: {
                                onAgree()
                            }) {
                                Text(agreeButtonText ?? "更新")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.3))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // 两个按钮的情况（普通通知）
                            if let onDisagree = onDisagree {
                                Button(action: {
                                    onDisagree()
                                }) {
                                    Text("不同意")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.2))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if let onAgree = onAgree {
                                Button(action: {
                                    onAgree()
                                }) {
                                    Text(agreeButtonText ?? "同意")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.3))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .zIndex(1000)
        }
    }
}

