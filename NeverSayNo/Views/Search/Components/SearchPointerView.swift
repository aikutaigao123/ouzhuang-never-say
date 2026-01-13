import SwiftUI
import CoreLocation

struct SearchPointerView: View {
    @ObservedObject var locationManager: LocationManager
    let randomRecord: LocationRecord?
    @Binding var showPointer: Bool // 🎯 新增：控制指针显示状态
    
    var body: some View {
        if showPointer {
            if let currentLocation = locationManager.location {
                if let record = randomRecord {
                    SearchPointerWithMatch(
                        currentLocation: currentLocation,
                        record: record,
                        headingValue: locationManager.heading?.trueHeading ?? 0
                    )
                } else {
                    SearchPointerNorth(
                        headingValue: locationManager.heading?.trueHeading ?? 0
                    )
                }
            } else {
                SearchPointerNorth(
                    headingValue: locationManager.heading?.trueHeading ?? 0
                )
            }
        }
    }
}
