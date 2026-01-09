import SwiftUI

// MARK: - RankingView Upload Extension
extension RankingView {
    
    // 自动刷新界面
    private func autoRefresh() {
        guard !isAutoRefreshing else {
            return
        }
        
        isAutoRefreshing = true
        
        // 延迟一点时间后刷新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.refreshTrigger = UUID()
            self.isAutoRefreshing = false
        }
    }
    
    // 静默刷新 - 在后台刷新数据，准备好后再显示
    func silentRefresh() {
        guard !isRefreshingSilently else {
            return
        }
        
        isRefreshingSilently = true
        isDataReady = false
        
        // 重新加载数据
        preloadUploadData()
        
        // 给数据加载一些时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.uploadUser != nil && self.uploadLocation != nil && !self.uploadData.isEmpty {
                self.isDataReady = true
                self.isRefreshingSilently = false
            } else {
                // 如果数据还没准备好，再等一会
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isDataReady = true
                    self.isRefreshingSilently = false
                }
            }
        }
    }
    
    // 执行实际上传
    /// ⚖️ 法律合规说明：
    /// 此方法确保所有上传到服务器的坐标都是 GCJ-02 坐标系，符合《中华人民共和国测绘法》要求
    func performActualUpload() {
        // 防止重复上传
        guard !isUploading else {
            return
        }
        
        guard !uploadData.isEmpty,
              uploadLocation != nil,
              uploadUser != nil else {
            uploadMessage = "上传数据准备失败"
            showUploadAlert = true
            return
        }
        
        // ⚖️ 法律合规：确定最终上传的经纬度（必须使用 GCJ-02 坐标）
        // 根据《测绘法》要求，所有上传到服务器的坐标都必须是 GCJ-02 坐标系
        let finalLatitude: Double
        let finalLongitude: Double
        
        if let geocodedLat = geocodedLatitude, let geocodedLon = geocodedLongitude {
            // ⚖️ 法律合规：使用地址解析的经纬度（高德 API 返回的已经是 GCJ-02，直接使用）
            finalLatitude = geocodedLat
            finalLongitude = geocodedLon
        } else if let rawLat = rawLatitude, let rawLon = rawLongitude {
            // ⚖️ 法律合规：使用保存的原始坐标（WGS-84），必须转换为 GCJ-02 后上传
            // ❌ 禁止直接上传 WGS-84 坐标
            let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                latitude: rawLat,
                longitude: rawLon
            )
            finalLatitude = gcjLat
            finalLongitude = gcjLon
        } else {
            // ⚖️ 法律合规：用户手动修改了显示的坐标（UI 显示的已经是 GCJ-02，直接使用）
            guard let gcjLat = Double(editableLatitude),
                  let gcjLon = Double(editableLongitude) else {
                uploadMessage = "经纬度格式不正确"
                showUploadAlert = true
                return
            }
            
            finalLatitude = gcjLat
            finalLongitude = gcjLon
        }
        
        // 检查必填项：地名和推荐理由
        guard !editablePlaceName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationErrorMessage = "请输入地名"
            showValidationError = true
            return
        }
        
        guard !editableReason.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationErrorMessage = "请输入推荐理由"
            showValidationError = true
            return
        }
        
        // 立即关闭确认界面
        showConfirmDialog = false
        
        // ⚖️ 法律合规：更新 uploadData 中的经纬度为 GCJ-02 坐标
        // finalLatitude 和 finalLongitude 已经是 GCJ-02 坐标系
        var updatedData = uploadData
        updatedData["latitude"] = finalLatitude
        updatedData["longitude"] = finalLongitude
        if !editableAddress.isEmpty {
            updatedData["address"] = editableAddress
        }
        // 地名和推荐理由为必填项
        updatedData["placeName"] = editablePlaceName.trimmingCharacters(in: .whitespaces)
        updatedData["reason"] = editableReason.trimmingCharacters(in: .whitespaces)
        // 邮箱为选填项（如果用户填写，则同时覆盖 userEmail）
        let trimmedEmail = editableEmail.trimmingCharacters(in: .whitespaces)
        if !trimmedEmail.isEmpty {
            updatedData["email"] = trimmedEmail
            updatedData["userEmail"] = trimmedEmail
        }
        
        // 打印上传内容
        for (_, _) in updatedData.sorted(by: { $0.key < $1.key }) {
        }
        
        isUploading = true
        
        for key in ["placeName","reason","email","latitude","longitude","userId","userName"] {
            if updatedData[key] != nil {
            }
        }
        
        // 上传推荐数据到Recommendation表（使用更新后的数据）
        LeanCloudService.shared.uploadRecommendation(data: updatedData) { success, message, objectId in
            DispatchQueue.main.async {
                self.isUploading = false
                if success {
                    // 🎯 新增：上传成功后立刻刷新推荐榜，并高亮显示新上传的项目
                    if let newObjectId = objectId {
                        // 通过通知传递新上传的项目ID，让推荐榜高亮显示
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RefreshRecommendationList"),
                            object: nil,
                            userInfo: ["selectedRecommendationId": newObjectId]
                        )
                    } else {
                        // 如果没有 objectId，只刷新列表
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RefreshRecommendationList"),
                            object: nil
                        )
                    }
                    // 上传成功后清理数据
                    self.clearUploadData()
                } else {
                    if message.contains("API密钥配置错误") {
                        self.uploadMessage = "API配置错误：\n请检查LeanCloud配置\n\n错误详情：\(message)\n\n建议：\n1. 检查App ID和App Key是否正确\n2. 确认Server URL格式\n3. 点击'API配置检查'按钮进行诊断"
                    } else {
                        self.uploadMessage = "推荐上传失败：\(message)"
                    }
                    self.showUploadAlert = true
                }
                
                // 清空待上传数据
                self.clearUploadData()
            }
        }
    }
}

