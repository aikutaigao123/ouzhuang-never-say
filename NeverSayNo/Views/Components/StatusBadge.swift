import SwiftUI

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(status == "待处理" ? .orange : .green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status == "待处理" ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
            .cornerRadius(8)
    }
}
