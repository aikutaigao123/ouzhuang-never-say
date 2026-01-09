import SwiftUI
import CoreLocation

// 排行榜视图
struct RankingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager
    let onRankingItemTap: (UserScore) -> Void
    let onRecommendationItemTap: (RecommendationItem) -> Void
    let initialTab: Int
    let selectedRecommendationId: String?
    let selectedRankingId: String? // 🎯 新增：当前选中的排行榜项目ID
    
    // 初始化方法
    init(locationManager: LocationManager, userManager: UserManager, onRankingItemTap: @escaping (UserScore) -> Void, onRecommendationItemTap: @escaping (RecommendationItem) -> Void, initialTab: Int = 0, selectedRecommendationId: String? = nil, selectedRankingId: String? = nil) {
        self.locationManager = locationManager
        self.userManager = userManager
        self.onRankingItemTap = onRankingItemTap
        self.onRecommendationItemTap = onRecommendationItemTap
        self.initialTab = initialTab
        self.selectedRecommendationId = selectedRecommendationId
        self.selectedRankingId = selectedRankingId
        _selectedTab = State(initialValue: initialTab)
    }
    
    @State var isUploading = false
    @State var showUploadAlert = false
    @State var uploadMessage = ""
    @State var showConfirmDialog = false
    
    // 简化的数据管理 - 只使用一套数据
    @State var uploadData: [String: Any] = [:]
    @State var uploadUser: UserInfo?
    @State var uploadLocation: CLLocation?
    
    // 静默刷新机制
    @State var refreshTrigger = UUID()
    @State var isAutoRefreshing = false
    @State var isDataReady = false
    @State var isRefreshingSilently = false
    
    // 🎯 新增：控制子视图加载的标志
    @State private var shouldLoadRecommendation = false
    @State private var shouldLoadRanking = false
    
    // 🎯 新增：时间测量（从点击排行榜按钮到推荐榜完全显示）
    @State private var rankingButtonClickTime: Date?
    
    // 原始坐标（WGS-84，用于上传）
    @State var rawLatitude: Double?
    @State var rawLongitude: Double?
    
    // 可编辑的经纬度（GCJ-02，用于显示）
    @State var editableLatitude: String = ""
    @State var editableLongitude: String = ""
    @State var editableAddress: String = ""
    @State var editablePlaceName: String = ""
    @State var editableReason: String = ""
    @State var editableEmail: String = ""
    @State var isGeocoding = false
    @State var geocodedLatitude: Double?
    @State var geocodedLongitude: Double?
    @State var isGettingCurrentLocation = false
    @State var geocodingError: String? = nil
    @State var reversedAddress: String? = nil
    @State var locationUpdateTimer: Timer? = nil
    @State var reverseGeocodeTask: DispatchWorkItem? = nil
    @State var validationErrorMessage: String = ""
    @State var showValidationError: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标签栏
                HStack(spacing: 0) {
                    // 推荐榜标签（左侧）
                    Button(action: {
                        selectedTab = 0
                        // 点击排行/推荐按钮时就开始预加载数据
                        preloadUploadData()
                    }) {
                        VStack(spacing: 8) {
                            Text("推荐榜")
                                .font(.headline)
                                .fontWeight(selectedTab == 0 ? .semibold : .medium)
                                .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                                .fixedSize()
                            
                            // 下划线指示器
                            Rectangle()
                                .fill(selectedTab == 0 ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // 排行榜标签（右侧）
                    Button(action: {
                        selectedTab = 1
                        // 点击排行/推荐按钮时就开始预加载数据
                        preloadUploadData()
                    }) {
                        VStack(spacing: 8) {
                            Text("排行榜")
                                .font(.headline)
                                .fontWeight(selectedTab == 1 ? .semibold : .medium)
                                .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                                .fixedSize()
                            
                            // 下划线指示器
                            Rectangle()
                                .fill(selectedTab == 1 ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    // 推荐榜内容（左侧）
                    RecommendationListView(
                        locationManager: locationManager,
                        userManager: userManager, // 🎯 新增：传递 userManager
                        onRecommendationItemTap: onRecommendationItemTap,
                        selectedItemId: selectedRecommendationId,
                        shouldLoad: $shouldLoadRecommendation  // 🎯 新增：传递加载控制标志
                    )
                        .tag(0)
                    
                    // 排行榜内容（右侧）
                    RankingListView(
                        locationManager: locationManager,
                        userManager: userManager, // 🎯 新增：传递 userManager
                        onRankingItemTap: { item in
                            onRankingItemTap(item)
                        },
                        selectedItemId: selectedRankingId,
                        shouldLoad: $shouldLoadRanking  // 🎯 新增：传递加载控制标志
                    )
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("排行榜")
            .navigationBarTitleDisplayMode(.inline)
            // 🎯 修改：只在当前选中的 tab 显示时才触发加载，避免不必要的网络请求
            .onAppear {

                
                // 🎯 新增：记录点击排行榜按钮的时间（如果默认显示推荐榜）
                if initialTab == 0 {
                    let clickTime = Date()
                    rankingButtonClickTime = clickTime
                    // 使用 UserDefaults 存储，让子视图可以读取（按用户隔离）
                    if let userId = userManager.currentUser?.userId {
                        let key = "ranking_button_click_time_\(userId)"
                        UserDefaults.standard.set(clickTime, forKey: key)
                    }
                }
                
                // 根据初始 tab 决定加载哪个视图
                if initialTab == 0 {
                    // 默认显示推荐榜，立即加载推荐榜

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {

                        shouldLoadRecommendation = true
                    }
                } else {
                    // 默认显示排行榜，立即加载排行榜

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {

                        shouldLoadRanking = true
                    }
                }
            }
            // 🎯 新增：监听 tab 切换，只在切换到某个 tab 时才加载该 tab 的数据
            .onChange(of: selectedTab) { oldValue, newValue in
                
                if newValue == 0 && !shouldLoadRecommendation {
                    // 切换到推荐榜

                    shouldLoadRecommendation = true
                } else if newValue == 1 && !shouldLoadRanking {
                    // 切换到排行榜

                    shouldLoadRanking = true
                } else {

                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 检查是否已经有预加载的数据
                        if uploadUser != nil && uploadLocation != nil && !uploadData.isEmpty {
                            showConfirmDialog = true
                        } else {
                            uploadCurrentLocation()
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(isUploading)
                }
            }
            .alert("上传位置", isPresented: $showUploadAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(uploadMessage)
            }
            .sheet(isPresented: $showConfirmDialog) {
                if isDataReady && uploadUser != nil && uploadLocation != nil {
                    UploadConfirmSheet(
                        user: uploadUser,
                        location: uploadLocation,
                        data: uploadData,
                        editableLatitude: $editableLatitude,
                        editableLongitude: $editableLongitude,
                        editableAddress: $editableAddress,
                        editablePlaceName: $editablePlaceName,
                        editableReason: $editableReason,
                        editableEmail: $editableEmail,
                        isGeocoding: $isGeocoding,
                        geocodingError: $geocodingError,
                        reversedAddress: $reversedAddress,
                        isGettingCurrentLocation: $isGettingCurrentLocation,
                        validationErrorMessage: $validationErrorMessage,
                        showValidationError: $showValidationError,
                        onCancel: {
                            clearUploadData()
                        },
                        onConfirm: {
                            performActualUpload()
                        },
                        onAutoRefresh: {
                            silentRefresh()
                        },
                        onGeocodeAddress: {
                            geocodeAddress()
                        },
                        onGetCurrentLocation: {
                            getCurrentLocation()
                        },
                        onTriggerReverseGeocode: {
                            triggerReverseGeocode()
                        }
                    )
                    .onAppear {
                        // 显示确认对话框时启动定时器
                        startLocationUpdateTimer()
                    }
                    .onDisappear {
                        // 关闭确认对话框时停止定时器
                        stopLocationUpdateTimer()
                    }
                } else {
                    // 显示加载界面
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在准备上传信息...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if isRefreshingSilently {
                            Text("正在刷新数据...")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                    .onAppear {
                        silentRefresh()
                    }
                }
            }
        }
        .id(refreshTrigger)
    }
    
    // 反向地理编码：根据经纬度获取地址
    func reverseGeocodeLocation(latitude: Double, longitude: Double) {
        AddressGeocodingService.shared.reverseGeocode(latitude: latitude, longitude: longitude) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let address):
                    self.reversedAddress = address
                case .failure:
                    self.reversedAddress = nil
                }
            }
        }
    }
    
    // 停止位置更新定时器
    func stopLocationUpdateTimer() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
}

#Preview {
    RankingView(locationManager: LocationManager(), userManager: UserManager(), onRankingItemTap: { _ in }, onRecommendationItemTap: { _ in }, initialTab: 0, selectedRecommendationId: nil, selectedRankingId: nil)
}