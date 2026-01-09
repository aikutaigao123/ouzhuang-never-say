import SwiftUI

struct MatchResultInfoRowView: View {
    let record: LocationRecord
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - 40, 100) // 确保最小宽度
            let itemCount = TimezoneUtils.shouldShowTimezone(record.longitude) ? 3 : 2
            let spacingWidth = CGFloat(itemCount - 1) * 20
            let estimatedItemWidth = max((availableWidth - spacingWidth) / CGFloat(itemCount), 20) // 确保最小宽度
            let baseScale = min(1.0, max(estimatedItemWidth / 60, 0.1)) // 确保最小缩放
            let deviceScale = UIScreen.main.bounds.width < 375 ? 0.65 : 1.0
            let contentScale = UIScreen.main.bounds.width < 320 ? 0.55 : 1.0
            let finalScale = max(baseScale * deviceScale * contentScale, 0.1) // 确保最小缩放值
            
            HStack(spacing: getSpacing(for: finalScale)) {
                DistanceInfoView(
                    record: record,
                    locationManager: locationManager,
                    scale: finalScale
                )
                
                TimeInfoView(
                    record: record,
                    scale: finalScale
                )
                
                if TimezoneUtils.shouldShowTimezone(record.longitude) {
                    TimezoneInfoView(
                        record: record,
                        scale: finalScale
                    )
                }
            }
            .scaleEffect(finalScale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 80)
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.3), value: TimezoneUtils.shouldShowTimezone(record.longitude))
        .clipped()
    }
    
    private func getSpacing(for scale: CGFloat) -> CGFloat {
        // 确保 scale 是有效值
        let validScale = max(scale, 0.1)
        
        if validScale < 0.6 {
            if validScale < 0.3 { return 1 }
            if validScale < 0.4 { return 2 }
            if validScale < 0.5 { return 5 }
            return 10
        }
        return 20
    }
}