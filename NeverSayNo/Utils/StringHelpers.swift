import SwiftUI
import Foundation

struct StringHelpers {
    // 检查字符串是否为空或只包含空白字符
    static func isEmptyOrWhitespace(_ string: String) -> Bool {
        return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // 截取字符串到指定长度
    static func truncate(_ string: String, to length: Int) -> String {
        if string.count <= length {
            return string
        }
        let index = string.index(string.startIndex, offsetBy: length)
        return String(string[..<index]) + "..."
    }
    
    // 移除字符串中的特殊字符
    static func removeSpecialCharacters(_ string: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces)
        return string.components(separatedBy: allowedCharacters.inverted).joined()
    }
    
    // 检查字符串是否为有效邮箱（支持emoji）
    static func isValidEmail(_ email: String) -> Bool {
        // 🎯 修改：使用统一的验证工具，支持emoji
        return ValidationUtils.isValidEmail(email)
    }
    
    // 检查字符串是否为有效手机号
    static func isValidPhoneNumber(_ phone: String) -> Bool {
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }
    
    // 格式化手机号显示
    static func formatPhoneNumber(_ phone: String) -> String {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
        if cleaned.count == 11 {
            let start = String(cleaned.prefix(3))
            let middle = String(cleaned.dropFirst(3).prefix(4))
            let end = String(cleaned.suffix(4))
            return "\(start) \(middle) \(end)"
        }
        return phone
    }
    
    // 获取字符串的MD5哈希值
    static func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = data.withUnsafeBytes { bytes in
            return bytes.bindMemory(to: UInt8.self)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // 检查字符串是否包含中文字符
    static func containsChinese(_ string: String) -> Bool {
        return string.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
    
    // 获取字符串的拼音首字母
    static func getPinyinInitial(_ string: String) -> String {
        let mutableString = NSMutableString(string: string)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        let transformedString = String(mutableString)
        if !transformedString.isEmpty {
            return String(transformedString.prefix(1)).uppercased()
        }
        return ""
    }
    
    // 检查字符串是否为纯数字
    static func isNumeric(_ string: String) -> Bool {
        return string.allSatisfy { $0.isNumber }
    }
    
    // 格式化文件大小
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // 获取字符串的UTF-8字节数
    static func utf8ByteCount(_ string: String) -> Int {
        return string.utf8.count
    }
    
    // 限制字符串到指定的字节数（0.7KB = 700字节）
    static func limitToBytes(_ string: String, maxBytes: Int = 700) -> String {
        let utf8Bytes = string.utf8
        if utf8Bytes.count <= maxBytes {
            return string
        }
        
        // 从后往前截断，确保不超过字节限制
        var result = ""
        var currentBytes = 0
        
        for char in string {
            let charBytes = String(char).utf8.count
            if currentBytes + charBytes > maxBytes {
                break
            }
            result.append(char)
            currentBytes += charBytes
        }
        
        return result
    }
}
