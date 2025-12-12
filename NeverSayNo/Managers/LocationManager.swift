import SwiftUI
import CoreLocation

// 位置管理器类
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var heading: CLHeading? // 新增：设备朝向
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0 // 1米变化时更新位置
        // 不启动持续的方向更新，只在需要时获取
    }
    
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    // 开始持续位置更新
    func startUpdatingLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    // 停止持续位置更新
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func startHeadingUpdates() {
        if CLLocationManager.headingAvailable() {
            locationManager.headingFilter = 1 // 1度变化才回调
            locationManager.startUpdatingHeading()
        }
    }
    
    func stopHeadingUpdates() {
        locationManager.stopUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            if let newLocation = locations.first {
                self.location = newLocation
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    break
                case .locationUnknown:
                    break
                case .network:
                    break
                default:
                    break
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                // 如果已经在更新位置，继续更新；否则只请求一次位置
                if manager.location != nil {
                    self.locationManager.startUpdatingLocation()
                } else {
                    self.locationManager.requestLocation()
                }
            case .denied:
                break
            case .restricted:
                break
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.heading = newHeading
        }
    }
}
