import SwiftUI

// MARK: - Button Components
extension AvatarZoomView {
    
    // 连击进度视图 - 已移除不会显示的UI元素
    struct ComboProgressView: View {
        let comboCount: Int
        let maxComboCount: Int
        let isLongPressing: Bool
        
        var body: some View {
            // 由于显示条件错误，此视图永远不会显示，保留空实现
            EmptyView()
        }
    }
}
