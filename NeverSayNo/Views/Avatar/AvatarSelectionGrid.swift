import SwiftUI

struct AvatarSelectionGrid: View {
    @ObservedObject var avatarManager: AvatarManager
    @Binding var currentAvatarEmoji: String?
    @ObservedObject var userManager: UserManager
    @Binding var searchText: String
    let onCopyEmoji: (String) -> Void
    
    @State private var searchDebounceTimer: Timer?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(avatarManager.sortedEmojis, id: \.self) { emoji in
                        AvatarGridItem(
                            emoji: emoji,
                            avatarManager: avatarManager,
                            currentAvatarEmoji: $currentAvatarEmoji,
                            userManager: userManager,
                            onCopyEmoji: onCopyEmoji
                        )
                        .id(emoji) // 为每个emoji添加ID用于滚动定位
                    }
                }
                .padding()
                
                // 底部说明文字
                AvatarDescriptionView()
            }
            .onChange(of: searchText) { _, newSearchText in
                // 取消之前的定时器
                searchDebounceTimer?.invalidate()
                
                // 当搜索文本变化时，延迟执行滚动到对应的emoji位置
                if !newSearchText.isEmpty {
                    searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        scrollToEmoji(newSearchText, proxy: proxy)
                    }
                }
            }
        }
    }
    
    // 滚动到指定emoji的函数
    private func scrollToEmoji(_ searchText: String, proxy: ScrollViewProxy) {
        // 找到搜索文本中最后一个匹配的emoji（按搜索文本中的出现顺序）
        var lastMatchedEmoji: String? = nil
        var lastMatchedPosition: Int = -1
        
        // 遍历emoji表，找到搜索文本中最后一个匹配的emoji
        for emoji in avatarManager.sortedEmojis {
            if searchText.contains(emoji) {
                // 找到emoji在搜索文本中的位置
                if let range = searchText.range(of: emoji) {
                    let position = searchText.distance(from: searchText.startIndex, to: range.lowerBound)
                    
                    // 如果这个emoji在搜索文本中的位置更靠后，则更新为最后一个
                    if position > lastMatchedPosition {
                        lastMatchedEmoji = emoji
                        lastMatchedPosition = position
                    }
                }
            }
        }
        
        // 如果找到了匹配的emoji，滚动到最后一个匹配的位置
        if let targetEmoji = lastMatchedEmoji {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(targetEmoji, anchor: UnitPoint.center)
            }
        }
    }
}

struct AvatarDescriptionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)
            
            VStack(spacing: 2) {
                Text("解锁所有头像即可解锁双头像模式以及彩色用户名模式")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("双头像模式允许您组合两个头像，创造独特的个人标识")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

