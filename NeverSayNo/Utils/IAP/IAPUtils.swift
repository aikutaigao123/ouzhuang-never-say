import Foundation
import StoreKit

struct IAPUtils {
    // 格式化价格
    static func formatPrice(_ price: NSDecimalNumber, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: price) ?? "\(price)"
    }
    
    // 获取商品钻石映射
    static func getDiamondsForProduct(_ productId: String) -> Int? {
        let mapping = [
            "NeverSayNo10": 10,
            "NeverSayNo60": 60,
            "NeverSayNo500": 500,
            "NeverSayNo715": 715,
            "NeverSayNo1345": 1345,
            "NeverSayNo2100": 2100,
            "NeverSayNo3690": 3690,
            "NeverSayNo7400": 7400
        ]
        return mapping[productId]
    }
    
    // 验证商品ID是否有效
    static func isValidProductId(_ productId: String) -> Bool {
        return getDiamondsForProduct(productId) != nil
    }
    
    // 获取商品描述
    static func getProductDescription(_ productId: String) -> String {
        let diamonds = getDiamondsForProduct(productId) ?? 0
        return "\(diamonds) 钻石"
    }
}
