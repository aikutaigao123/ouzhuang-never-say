import Foundation

struct ValidationUtils {
    // 🎯 新增：从字符串中提取所有emoji（正确处理复合emoji）
    // 使用EmojiList来准确识别emoji，而不是依赖unicode属性（因为某些数字可能被误判）
    private static func extractEmojis(from string: String) -> [String] {
        var emojis: [String] = []
        var usedRanges: [Range<String.Index>] = []
        
        // 在EmojiList中查找所有emoji，按长度从长到短排序（避免部分匹配）
        let sortedEmojis = EmojiList.allEmojis.sorted { $0.count > $1.count }
        
        // 在字符串中查找每个emoji
        for emoji in sortedEmojis {
            var searchRange = string.startIndex..<string.endIndex
            
            while let range = string.range(of: emoji, range: searchRange) {
                // 检查这个范围是否与其他已找到的emoji重叠
                let isOverlapping = usedRanges.contains { usedRange in
                    range.overlaps(usedRange)
                }
                
                if !isOverlapping {
                    emojis.append(emoji)
                    usedRanges.append(range)
                }
                
                // 继续搜索下一个出现的位置
                if range.upperBound < string.endIndex {
                    searchRange = range.upperBound..<string.endIndex
                } else {
                    break
                }
            }
        }
        
        return emojis
    }
    
    // 🎯 新增：从字符串中移除所有emoji（使用EmojiList来准确识别）
    private static func removeEmojis(from string: String) -> String {
        var result = string
        
        // 在EmojiList中查找所有emoji，按长度从长到短排序（避免部分匹配）
        let sortedEmojis = EmojiList.allEmojis.sorted { $0.count > $1.count }
        
        // 移除所有找到的emoji
        for emoji in sortedEmojis {
            result = result.replacingOccurrences(of: emoji, with: "")
        }
        
        return result
    }
    
    // 验证邮箱格式（允许包含一个来自EmojiList的emoji）
    // 同时支持邮箱格式和微信号格式（包括带emoji的微信号）
    // 邮箱格式：user@example.com 或 user😀@example.com
    // 微信号格式：abc123 或 😀abc123（以字母开头，6-20字符）
    static func isValidEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 🎯 检查并提取emoji
        let emojis = extractEmojis(from: trimmedEmail)
        
        // 如果包含emoji，验证emoji
        if !emojis.isEmpty {
            // 只允许一个emoji
            guard emojis.count == 1 else {
                return false
            }
            
            let emoji = emojis[0]
            // 检查emoji是否在EmojiList中
            guard EmojiList.allEmojis.contains(emoji) else {
                return false
            }
            
            // 移除emoji后验证剩余部分（支持邮箱格式或微信号格式）
            let emailWithoutEmoji = removeEmojis(from: trimmedEmail)
            return isValidEmailWithoutEmoji(emailWithoutEmoji)
        }
        
        // 没有emoji，使用原有验证逻辑（支持邮箱格式或微信号格式）
        return isValidEmailWithoutEmoji(trimmedEmail)
    }
    
    // 🎯 验证不包含emoji的邮箱或微信号格式
    // 如果包含@符号，验证为邮箱格式
    // 如果不包含@符号，验证为微信号格式（以字母开头，6-20字符，允许字母、数字、下划线、连字符）
    private static func isValidEmailWithoutEmoji(_ email: String) -> Bool {
        // 1. 先检查是否是邮箱格式（包含@符号）
        if email.contains("@") {
            let parts = email.components(separatedBy: "@")
            guard parts.count == 2 else {
                return false
            }
            
            let localPart = parts[0]
            let domainPart = parts[1]
            
            guard !localPart.isEmpty && localPart.count <= 64 else {
                return false
            }
            guard !domainPart.isEmpty && domainPart.contains(".") else {
                return false
            }
            
            let domainParts = domainPart.components(separatedBy: ".")
            guard domainParts.count >= 2 else {
                return false
            }
            
            guard let topLevelDomain = domainParts.last, topLevelDomain.count >= 2 else {
                return false
            }
            
            let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
            let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
            return emailPredicate.evaluate(with: email)
        }
        
        // 2. 如果不包含@符号，验证为微信号格式
        // 微信号格式要求：以字母开头，总长度6-20字符，只能包含字母、数字、下划线、连字符
        let wechatIdRegex = "^[a-zA-Z][a-zA-Z0-9_-]{5,19}$"
        let wechatIdPredicate = NSPredicate(format:"SELF MATCHES %@", wechatIdRegex)
        return wechatIdPredicate.evaluate(with: email)
    }
    
    // 验证表单是否有效
    static func isFormValid(username: String, password: String, confirmPassword: String) -> Bool {
        return !username.isEmpty && 
               !password.isEmpty && 
               !confirmPassword.isEmpty && 
               password == confirmPassword &&
               password.count >= 6
    }
    
    // 验证用户名格式
    static func isValidUsername(_ username: String) -> Bool {
        let filtered = username.filter { char in
            char.isLetter || char.isNumber || char == "-"
        }
        return filtered == username && !username.isEmpty
    }
    
    // 验证密码格式
    static func isValidPassword(_ password: String) -> Bool {
        let filtered = password.filter { char in
            char.isLetter || char.isNumber || "!@#$%^&*()_+-=[]{}|;:,.<>?".contains(char)
        }
        return filtered == password && !password.isEmpty
    }
}
