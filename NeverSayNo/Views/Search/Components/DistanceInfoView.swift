import SwiftUI
import CoreLocation

struct DistanceInfoView: View {
    let record: LocationRecord
    @ObservedObject var locationManager: LocationManager
    let scale: CGFloat
    
    var body: some View {
        if let currentLocation = locationManager.location {
            // ⚖️ 坐标系转换：LocationRecord中存储的是GCJ-02坐标，需要转回WGS-84才能与当前位置（WGS-84）正确计算距离
            let (wgsLat, wgsLon) = CoordinateConverter.gcj02ToWgs84(
                latitude: record.latitude,
                longitude: record.longitude
            )
            let distance = DistanceUtils.calculateDistance(
                from: currentLocation,
                to: wgsLat,
                targetLongitude: wgsLon
            )
            
            VStack(spacing: getVerticalSpacing()) {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 24))
                Text(DistanceUtils.formatDistance(distance))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
        }
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
