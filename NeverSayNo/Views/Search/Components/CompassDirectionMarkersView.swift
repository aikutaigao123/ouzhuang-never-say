import SwiftUI

struct CompassDirectionMarkersView: View {
    @ObservedObject var locationManager: LocationManager
    
    private let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    
    var body: some View {
        ForEach(0..<8, id: \.self) { index in
            CompassDirectionMarker(
                direction: directions[index],
                index: index,
                headingValue: locationManager.heading?.trueHeading ?? 0
            )
        }
    }
}
