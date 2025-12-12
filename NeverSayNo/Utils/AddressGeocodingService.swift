import Foundation
import CoreLocation

class AddressGeocodingService: ObservableObject {
    static let shared = AddressGeocodingService()
    
    // 高德地图API密钥
    private let apiKey = "a28106db5232e0de5d6ef9bd699ad289"
    private let baseURL = "https://restapi.amap.com/v3/geocode/geo"
    
    private init() {}
    
    // 地址解析：中文地址转经纬度（多级策略：高德地图 -> CLGeocoder）
    func geocodeAddress(_ address: String, completion: @escaping (Result<(latitude: Double, longitude: Double), Error>) -> Void) {
        guard !address.isEmpty else {
            completion(.failure(GeocodingError.emptyAddress))
            return
        }
        
        // 第一步：尝试高德地图API
        tryAMapGeocoding(address) { result in
            switch result {
            case .success(let coordinates):
                completion(.success(coordinates))
            case .failure(_):
                // 第二步：高德地图失败，尝试CLGeocoder
                self.tryCLGeocoding(address) { clResult in
                    switch clResult {
                    case .success(let coordinates):
                        completion(.success(coordinates))
                    case .failure(let clError):
                        completion(.failure(clError))
                    }
                }
            }
        }
    }
    
    // 高德地图地址解析
    private func tryAMapGeocoding(_ address: String, completion: @escaping (Result<(latitude: Double, longitude: Double), Error>) -> Void) {
        // 构建请求URL
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "output", value: "JSON")
        ]
        
        guard let url = components?.url else {
            completion(.failure(GeocodingError.invalidURL))
            return
        }
        
        // 发起网络请求
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(GeocodingError.noData))
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(GeocodingResponse.self, from: data)
                    
                    if result.status == "1" && !result.geocodes.isEmpty {
                        let geocode = result.geocodes[0]
                        let location = geocode.location.components(separatedBy: ",")
                        
                        if location.count == 2,
                           let longitude = Double(location[0]),
                           let latitude = Double(location[1]) {
                            // 检查解析出的坐标是否有效
                            guard !latitude.isNaN && !longitude.isNaN && !latitude.isInfinite && !longitude.isInfinite else {
                                completion(.failure(GeocodingError.invalidLocation))
                                return
                            }
                            completion(.success((latitude: latitude, longitude: longitude)))
                        } else {
                            completion(.failure(GeocodingError.invalidLocation))
                        }
                    } else {
                        completion(.failure(GeocodingError.noResults))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // CLGeocoder地址解析
    private func tryCLGeocoding(_ address: String, completion: @escaping (Result<(latitude: Double, longitude: Double), Error>) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(address) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    completion(.failure(GeocodingError.noResults))
                    return
                }
                
                guard let location = placemark.location else {
                    completion(.failure(GeocodingError.invalidLocation))
                    return
                }
                
                let latitude = location.coordinate.latitude
                let longitude = location.coordinate.longitude
                
                // 检查坐标是否有效
                guard !latitude.isNaN && !longitude.isNaN && !latitude.isInfinite && !longitude.isInfinite else {
                    completion(.failure(GeocodingError.invalidLocation))
                    return
                }
                
                completion(.success((latitude: latitude, longitude: longitude)))
            }
        }
    }
    
    // 反向地理编码：经纬度转地址（使用高德地图API）
    func reverseGeocode(latitude: Double, longitude: Double, completion: @escaping (Result<String, Error>) -> Void) {
        // 构建请求URL
        let urlString = "https://restapi.amap.com/v3/geocode/regeo"
        var components = URLComponents(string: urlString)
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "location", value: "\(longitude),\(latitude)"),
            URLQueryItem(name: "output", value: "JSON")
        ]
        
        guard let url = components?.url else {
            completion(.failure(GeocodingError.invalidURL))
            return
        }
        
        // 发起网络请求
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(GeocodingError.noData))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let status = json?["status"] as? String, status == "1" {
                        if let regeocode = json?["regeocode"] as? [String: Any],
                           let formattedAddress = regeocode["formatted_address"] as? String {
                            completion(.success(formattedAddress))
                        } else {
                            completion(.failure(GeocodingError.noResults))
                        }
                    } else {
                        completion(.failure(GeocodingError.noResults))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

// 响应数据模型
struct GeocodingResponse: Codable {
    let status: String
    let info: String
    let geocodes: [Geocode]
}

struct Geocode: Codable {
    let location: String
    let level: String
    let country: String
    let province: String
    let city: String
    let district: [String]?
    let township: [String]?
    let street: [String]?
    let number: [String]?
    let adcode: String
    let formatted_address: String
    let citycode: String?
    
    // 添加自定义编码键，处理可选字段
    enum CodingKeys: String, CodingKey {
        case location, level, country, province, city, district, township, street, number, adcode, formatted_address, citycode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        location = try container.decode(String.self, forKey: .location)
        level = try container.decode(String.self, forKey: .level)
        country = try container.decode(String.self, forKey: .country)
        province = try container.decode(String.self, forKey: .province)
        city = try container.decode(String.self, forKey: .city)
        adcode = try container.decode(String.self, forKey: .adcode)
        formatted_address = try container.decode(String.self, forKey: .formatted_address)
        
        // 处理可能为空的数组字段
        district = try? container.decode([String].self, forKey: .district)
        township = try? container.decode([String].self, forKey: .township)
        street = try? container.decode([String].self, forKey: .street)
        number = try? container.decode([String].self, forKey: .number)
        citycode = try? container.decode(String.self, forKey: .citycode)
    }
}

// 错误类型
enum GeocodingError: Error, LocalizedError {
    case emptyAddress
    case invalidURL
    case noData
    case noResults
    case invalidLocation
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyAddress:
            return "地址不能为空"
        case .invalidURL:
            return "无效的请求URL"
        case .noData:
            return "没有接收到数据"
        case .noResults:
            return "未找到该地址的坐标信息"
        case .invalidLocation:
            return "返回的坐标格式无效"
        case .apiError(let message):
            return "API错误: \(message)"
        }
    }
}
