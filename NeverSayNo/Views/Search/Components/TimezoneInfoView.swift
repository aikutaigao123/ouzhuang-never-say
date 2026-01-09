import SwiftUI

struct TimezoneInfoView: View {
    let record: LocationRecord
    let scale: CGFloat
    
    var body: some View {
        VStack(spacing: getVerticalSpacing()) {
            Image(systemName: "clock.badge")
                .foregroundColor(.blue)
                .font(.system(size: 24))
            Text(TimezoneUtils.calculateTimezoneFromLongitude(record.longitude))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func getVerticalSpacing() -> CGFloat {
        if scale < 0.6 {
            if scale < 0.3 { return 0 }
            if scale < 0.4 { return 1 }
            if scale < 0.5 { return 2 }
            return 4
        }
        return 6
    }
}
