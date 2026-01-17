import SwiftUI
import CoreLocation

// 上传确认对话框
struct UploadConfirmSheet: View {
    let user: UserInfo?
    let location: CLLocation?
    let data: [String: Any]
    @Binding var editableLatitude: String
    @Binding var editableLongitude: String
    @Binding var editableAddress: String
    @Binding var editablePlaceName: String
    @Binding var editableReason: String
    @Binding var editableEmail: String
    @Binding var isGeocoding: Bool
    @Binding var geocodingError: String?
    @Binding var reversedAddress: String?
    @Binding var isGettingCurrentLocation: Bool
    @Binding var validationErrorMessage: String
    @Binding var showValidationError: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void
    let onAutoRefresh: () -> Void
    let onGeocodeAddress: () -> Void
    let onGetCurrentLocation: () -> Void
    let onTriggerReverseGeocode: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        // 标题区域
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            Text("确认上传位置")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // 用户信息 - 已隐藏
                    // if let user = user {
                    //     VStack(alignment: .leading, spacing: 8) {
                    //         Text("👤 用户信息")
                    //             .font(.subheadline)
                    //             .fontWeight(.semibold)
                    //             .foregroundColor(.blue)
                    //         
                    //         Text("姓名：\(user.fullName)")
                    //         Text("ID：\(user.userId)")
                    //         Text("类型：\(user.loginType.toString())")
                    //         if let email = user.email, !email.isEmpty {
                    //             Text("邮箱：\(email)")
                    //         }
                    //     }
                    //     .padding(.vertical, 8)
                    //     .padding(.horizontal, 12)
                    //     .background(Color.blue.opacity(0.1))
                    //     .cornerRadius(8)
                    //     .onAppear {
                    //     }
                    // } else {
                    //     Text("❌ UploadConfirmSheet中user为nil")
                    //         .foregroundColor(.red)
                    //         .onAppear {
                    //             // 触发静默刷新
                    //             DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    //                 onAutoRefresh()
                    //             }
                    //         }
                    // }
                    
                    // 🎯 修改：地名输入框（放在前面）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            
                            HStack(spacing: 2) {
                                Text("地名")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("*")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        TextField("请输入地名", text: Binding(
                            get: { editablePlaceName },
                            set: { newValue in
                                editablePlaceName = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                            }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    // 🎯 修改：推荐理由输入框（放在前面）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.indigo)
                                .font(.title3)
                            
                            HStack(spacing: 2) {
                                Text("推荐理由")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("*")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        TextField("请输入推荐理由", text: Binding(
                            get: { editableReason },
                            set: { newValue in
                                editableReason = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                            }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    // 🎯 新增：邮箱输入框（放在推荐理由下）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            
                            Text("邮箱")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        let emailBinding = Binding<String>(
                            get: { editableEmail },
                            set: { newValue in
                                editableEmail = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                            }
                        )
                        TextField("请输入邮箱（选填）", text: emailBinding)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    // 位置信息卡片
                    if let location = location {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                
                                Text("位置信息")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: onGetCurrentLocation) {
                                    HStack(spacing: 6) {
                                        if isGettingCurrentLocation {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("获取中...")
                                        } else {
                                            Image(systemName: "location.fill")
                                            Text("使用当前位置")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isGettingCurrentLocation ? Color.gray : Color.blue)
                                    .cornerRadius(8)
                                }
                                .disabled(isGettingCurrentLocation)
                            }
                            
                            VStack(spacing: 12) {
                                // 坐标显示区域（只读）
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("纬度")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(editableLatitude.isEmpty ? "未获取" : editableLatitude)
                                            .font(.subheadline)
                                            .foregroundColor(editableLatitude.isEmpty ? .secondary : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color(.systemGray4), lineWidth: 1)
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("经度")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(editableLongitude.isEmpty ? "未获取" : editableLongitude)
                                            .font(.subheadline)
                                            .foregroundColor(editableLongitude.isEmpty ? .secondary : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color(.systemGray4), lineWidth: 1)
                                            )
                                    }
                                }
                                
                                // 坐标系说明
                                Text("坐标系：GCJ-02（国测局坐标系）")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                                
                                // 反向地理编码地址（在精度前面）
                                if let address = reversedAddress {
                                    Text("📍 \(address)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                                
                                // 精度信息
                                HStack {
                                    Image(systemName: "target")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    
                                    Text("精度: \(String(format: "%.1f", location.horizontalAccuracy))米")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundColor(.red)
                            
                            Text("位置信息加载失败")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("正在尝试重新获取...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red.opacity(0.1))
                        )
                        .onAppear {
                            // 触发静默刷新
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onAutoRefresh()
                            }
                        }
                    }
                    
                    // 设备信息 - 已隐藏
                    // VStack(alignment: .leading, spacing: 8) {
                    //     Text("📱 设备信息")
                    //         .font(.subheadline)
                    //         .fontWeight(.semibold)
                    //         .foregroundColor(.purple)
                    //     
                    //     if let avatar = data["userAvatar"] as? String {
                    //         Text("😀 头像：\(avatar)")
                    //     }
                    //     if let deviceId = data["deviceId"] as? String {
                    //         Text("设备ID：\(deviceId)")
                    //     }
                    //     if let timezone = data["timezone"] as? String {
                    //         Text("🌍 时区：\(timezone)")
                    //     }
                    //     if let deviceTime = data["deviceTime"] as? String {
                    //         Text("⏰ 时间：\(deviceTime)")
                    //     }
                    // }
                    // .padding(.vertical, 8)
                    // .padding(.horizontal, 12)
                    // .background(Color.purple.opacity(0.1))
                    // .cornerRadius(8)
                    
                    // 地址输入框 - 已隐藏
                    // VStack(alignment: .leading, spacing: 12) {
                    //     HStack {
                    //         Image(systemName: "map.fill")
                    //             .foregroundColor(.orange)
                    //             .font(.title3)
                    //         
                    //         Text("地址")
                    //             .font(.headline)
                    //             .fontWeight(.semibold)
                    //             .foregroundColor(.primary)
                    //         
                    //         Spacer()
                    //         
                    //         if isGeocoding {
                    //             HStack(spacing: 4) {
                    //                 ProgressView()
                    //                     .scaleEffect(0.7)
                    //                 Text("解析中...")
                    //                     .font(.caption)
                    //                     .foregroundColor(.orange)
                    //             }
                    //         } else if let error = geocodingError {
                    //             HStack(spacing: 4) {
                    //                 Image(systemName: "exclamationmark.triangle.fill")
                    //                     .font(.caption)
                    //                     .foregroundColor(.red)
                    //                 Text(error)
                    //                     .font(.caption)
                    //                     .foregroundColor(.red)
                    //             }
                    //         }
                    //     }
                    //     
                    //     TextField("请输入地址，系统将自动解析为坐标", text: Binding(
                    //         get: { editableAddress },
                    //         set: { newValue in
                    //             editableAddress = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                    //         }
                    //     ))
                    //         .textFieldStyle(.roundedBorder)
                    //         .font(.body)
                    //         .padding(.horizontal, 12)
                    //         .padding(.vertical, 10)
                    //         .background(Color(.systemBackground))
                    //         .cornerRadius(12)
                    //         .overlay(
                    //             RoundedRectangle(cornerRadius: 12)
                    //                 .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    //         )
                    //         .onChange(of: editableAddress) { _, newAddress in
                    //             // 地址改变时清除错误信息
                    //             geocodingError = nil
                    //             
                    //             if !newAddress.isEmpty && !isGeocoding {
                    //                 DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    //                     if editableAddress == newAddress {
                    //                         onGeocodeAddress()
                    //                     }
                    //                 }
                    //             }
                    //         }
                    // }
                    // .padding(.horizontal, 20)
                    
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30) // 减少底部间距，让浮动按钮更靠近内容
            }
            
            // 浮动确定上传按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        onConfirm()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("确定上传")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
            }
            .navigationTitle("确认上传")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCancel) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("取消")
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .alert("提示", isPresented: $showValidationError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(validationErrorMessage)
            }
        }
        }
    }
}

