import SwiftUI

// 删除账号进度显示视图
struct DeleteAccountProgressView: View {
    @Binding var currentTable: String
    @Binding var completedTables: Int
    @Binding var totalTables: Int
    @Binding var currentDeletedCount: Int
    
    var progress: Double {
        guard totalTables > 0 else { return 0 }
        // 如果已完成所有表，显示100%
        if completedTables >= totalTables {
            return 1.0
        }
        // 🎯 计算进度：已完成表数 / 总表数
        // 注意：completedTables 在表删除完成后才增加，所以进度条会在每个表完成后更新
        let baseProgress = Double(completedTables) / Double(totalTables)
        // 如果当前有表在处理中，显示略大于已完成进度的值（视觉反馈）
        if !currentTable.isEmpty && completedTables < totalTables {
            return baseProgress + 0.01 // 轻微超出，表示正在处理
        }
        return baseProgress
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // 标题
            Text("正在删除账号数据")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            // 进度条区域
            VStack(spacing: 16) {
                // 进度百分比
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.orange)
                
                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        // 进度条 - 🎯 使用更平滑的动画，确保进度条正确更新
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(progress), height: 12)
                            .animation(.easeInOut(duration: 0.2), value: progress)
                    }
                }
                .frame(height: 12)
                .padding(.horizontal, 40)
                
                // 进度文字
                Text("已完成 \(completedTables) / \(totalTables) 个表")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
            
            // 当前操作信息
            VStack(spacing: 12) {
                Text("正在删除：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(currentTable.isEmpty ? "准备中..." : currentTable)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                if currentDeletedCount > 0 {
                    Text("已删除 \(currentDeletedCount) 条记录")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 20)
            .frame(minHeight: 100)
            
            // 提示信息
            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(1.2)
                
                Text("请稍候，正在安全删除您的所有数据...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

