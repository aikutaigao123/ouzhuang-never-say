import Foundation

struct ValidationUtils {
    // 验证邮箱格式
    static func isValidEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 先检查是否是邮箱格式
        if trimmedEmail.contains("@") {
            let parts = trimmedEmail.components(separatedBy: "@")
            guard parts.count == 2 else { return false }
            
            let localPart = parts[0]
            let domainPart = parts[1]
            
            guard !localPart.isEmpty && localPart.count <= 64 else { return false }
            guard !domainPart.isEmpty && domainPart.contains(".") else { return false }
            
            let domainParts = domainPart.components(separatedBy: ".")
            guard domainParts.count >= 2 else { return false }
            
            guard let topLevelDomain = domainParts.last, topLevelDomain.count >= 2 else { return false }
            
            let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
            let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
            return emailPredicate.evaluate(with: trimmedEmail)
        }
        
        let wechatIdRegex = "^[a-zA-Z][a-zA-Z0-9_-]{5,19}$"
        let wechatIdPredicate = NSPredicate(format:"SELF MATCHES %@", wechatIdRegex)
        return wechatIdPredicate.evaluate(with: trimmedEmail)
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
