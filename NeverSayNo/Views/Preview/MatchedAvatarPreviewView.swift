import SwiftUI

// 随机匹配对象头像放大预览（只展示，不含随机更换）
struct MatchedAvatarPreviewView: View {
    let avatar: String?
    let loginType: String?
    let userName: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                Group {
                    if let a = avatar, !a.isEmpty {
                        if a == "applelogo" {
                            Image(systemName: "applelogo")
                                .font(.system(size: 140))
                                .foregroundColor(.black)
                        } else if a == "person.circle.fill" {
                            Image(systemName: a)
                                .font(.system(size: 140))
                                .foregroundColor(.purple)
                        } else {
                            Text(a)
                                .font(.system(size: 140))
                        }
                    } else if let lt = loginType {
                        if lt == "apple" {
                            Image(systemName: "applelogo")
                                .font(.system(size: 140))
                                .foregroundColor(.black)
                        } else {
                            Image(systemName: "person.circle")
                                .font(.system(size: 140))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if let name = userName, !name.isEmpty {
                    Text(name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("头像预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
