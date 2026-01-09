import Foundation

// MARK: - 请求头设置扩展
extension LeanCloudService {
    
    // 设置LeanCloud请求头 - 修复请求头格式，与Manager app保持一致
    func setLeanCloudHeaders(_ request: inout URLRequest, contentType: String? = nil) {
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.setValue(appId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(appKey, forHTTPHeaderField: "X-LC-Key")
        request.setValue("NeverSayNo/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
    }
    
    // 生成ACL权限配置 - 修复权限问题
    func generateACL() -> [String: Any] {
        // 使用LeanCloud标准的ACL格式
        return [
            "*": [
                "read": true,
                "write": true
            ]
        ]
    }
    
    // 为数据添加ACL权限
    func addACLToData(_ data: [String: Any]) -> [String: Any] {
        let dataWithACL = data
        // 暂时注释掉ACL，避免格式错误
        // dataWithACL["ACL"] = generateACL()
        return dataWithACL
    }
}
