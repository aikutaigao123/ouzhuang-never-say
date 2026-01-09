import SwiftUI
import StoreKit

// 充值界面
struct RechargeView: View {
    @ObservedObject var diamondManager: DiamondManager
    @StateObject private var iapManager = IAPManager()
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRestoreSuccess = false
    @State private var showRestoreAlert = false
    @State private var isRestoring = false
    @State private var isRedeemingPromoCode = false
    @State private var showPromoCodeError = false
    @State private var promoCodeErrorMessage = ""
    @State private var diamondQueryRetryCount = 0  // 🎯 新增：钻石查询重试计数器
    
    var body: some View {
        mainContent
            .navigationTitle("充值钻石")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("购买失败", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("恢复购买", isPresented: $showRestoreAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("恢复成功", isPresented: $showRestoreSuccess) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("已恢复所有购买记录，钻石已添加到账户")
            }
            .alert("优惠代码兑换", isPresented: $showPromoCodeError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(promoCodeErrorMessage)
            }
            .onAppear {
                iapManager.fetchProducts()
                // 🎯 新增：每次打开充值界面时重新查询钻石余额（带重试机制）
                diamondQueryRetryCount = 0  // 重置重试计数器
                queryDiamondBalanceWithRetry()
            }
            .onChange(of: iapManager.purchaseError) { oldValue, newValue in
                handlePurchaseErrorChange(newValue)
            }
            .onChange(of: iapManager.productLoadError) { oldValue, newValue in
                if let error = newValue {
                    errorMessage = error
                    showError = true
                }
            }
            .onChange(of: iapManager.isPurchasing) { oldValue, newValue in
                handlePurchasingChange(newValue)
            }
            .onReceive(NotificationCenter.default.publisher(for: .iapPurchaseSuccessful)) { notification in
                handlePurchaseSuccessful(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .iapPurchaseDeferred)) { _ in
                handlePurchaseDeferred()
            }
            .onReceive(NotificationCenter.default.publisher(for: .iapRestoreCompleted)) { _ in
                handleRestoreCompleted()
            }
            .onReceive(NotificationCenter.default.publisher(for: .iapRestoreFailed)) { notification in
                handleRestoreFailed(notification)
            }
    }
    
    // MARK: - View Components
    private var mainContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    diamondBalanceCard
                    
                    // 🎯 新增：寻找按钮消耗说明（在框下方显示，仅当钻石数等于0时显示）
                    if diamondManager.diamonds == 0 {
                        searchButtonCostHint
                    }
                    
                    rechargeOptionsGrid
                    
                    // 恢复购买和兑换代码按钮
                    actionButtonsView
                    
                    // 🎯 App Store 要求：虚拟货币说明
                    virtualCurrencyDisclaimer
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .padding()
        }
    }
    
    private var diamondBalanceCard: some View {
        VStack(spacing: 15) {
            Text("💎 当前钻石余额")
                .font(UIStyleManager.Fonts.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("\(diamondManager.diamonds)")
                .font(UIStyleManager.Fonts.customRounded(size: 56, weight: .bold))
                .foregroundColor(.purple)
                .shadow(color: .purple.opacity(0.3), radius: 2, x: 0, y: 2)
                .id(diamondManager.diamonds) // 使用 id 触发平滑过渡
                .animation(.easeInOut(duration: 0.3), value: diamondManager.diamonds) // 平滑过渡
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // 🎯 新增：寻找按钮消耗说明（在框下方显示）
    private var searchButtonCostHint: some View {
        HStack(spacing: 8) {
            // 寻找按钮UI（禁用状态，仅用于显示，样式与SearchButtonContent一致）
            Button(action: {}) {
                HStack(spacing: 4) {
                    Text("💎")
                    Text("寻找")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .disabled(true)
            .background(Color.blue)
            .cornerRadius(10)
            
            Text("每次寻找消耗2💎钻石，即可进行真实匹配")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
    
    // 操作按钮视图（恢复购买和兑换代码）
    private var actionButtonsView: some View {
        HStack(spacing: 15) {
            // 恢复购买按钮
            Button(action: {
                isRestoring = true
                iapManager.restorePurchases()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("恢复购买")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(isRestoring || isProcessing)
            
            // 兑换代码按钮（iOS 14+）
            if #available(iOS 14.0, *) {
                Button(action: {
                    Task {
                        await redeemPromoCode()
                    }
                }) {
                    HStack {
                        Image(systemName: "ticket")
                        Text("兑换代码")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
                .disabled(isRedeemingPromoCode || isProcessing || isRestoring)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // 🎯 App Store 要求：虚拟货币说明（不可退款）
    private var virtualCurrencyDisclaimer: some View {
        VStack(spacing: 8) {
            Text("重要说明")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("钻石为虚拟货币，购买后不可退款。钻石用于应用内功能，无法兑换为现金或实物。")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Event Handlers
    private func handlePurchaseErrorChange(_ newValue: String?) {
        if let error = newValue {
            errorMessage = error
            showError = true
            isProcessing = false
        }
    }
    
    private func handlePurchasingChange(_ newValue: Bool) {
        if !newValue && iapManager.purchaseError == nil && isProcessing {
            isProcessing = false
        }
    }
    
    private func handlePurchaseSuccessful(_ notification: Notification) {
        isProcessing = false
        isRestoring = false
        
        if let isRestored = notification.userInfo?["isRestored"] as? Bool, isRestored {
            showRestoreSuccess = true
        }
    }
    
    private func handlePurchaseDeferred() {
        isProcessing = false
        errorMessage = "购买需要家长批准，请稍候"
        showError = true
    }
    
    private func handleRestoreCompleted() {
        isRestoring = false
        showRestoreSuccess = true
    }
    
    private func handleRestoreFailed(_ notification: Notification) {
        isRestoring = false
        if let error = notification.userInfo?["error"] as? String {
            errorMessage = error
        } else {
            errorMessage = "恢复购买失败"
        }
        showRestoreAlert = true
    }
    
    // 兑换优惠代码
    @available(iOS 14.0, *)
    @MainActor
    private func redeemPromoCode() async {
        isRedeemingPromoCode = true
        
        do {
            try await iapManager.presentPromoCodeRedeemSheet()
            // 兑换界面已显示，用户输入代码后会触发 transaction observer
            // 不需要在这里做额外处理，因为兑换成功会通过 transaction observer 处理
        } catch {
            promoCodeErrorMessage = "无法打开优惠代码兑换界面：\(error.localizedDescription)"
            showPromoCodeError = true
        }
        
        isRedeemingPromoCode = false
    }
    
    // 🎯 新增：查询钻石余额（带重试机制，参考用户头像查询）
    private func queryDiamondBalanceWithRetry() {
        // 调用 DiamondManager 的刷新方法
        diamondManager.refreshBalanceFromServer { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 查询成功，UI 会自动更新（因为 DiamondManager 是 @ObservedObject）
                    // 缓存也会自动更新（在 DiamondStore 的 refreshBalanceFromServer 中）
                    self.diamondQueryRetryCount = 0  // 重置重试计数器
                    
                case .failure:
                    
                    // 如果查询失败且未达到最大重试次数（2次），则重试
                    if self.diamondQueryRetryCount < 2 {
                        self.diamondQueryRetryCount += 1
                        
                        // 根据重试次数决定延迟时间（与用户名重试机制一致）
                        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
                        let delay: TimeInterval = self.diamondQueryRetryCount == 1 ? 1.0 / 17.0 : 0.5
                        
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.queryDiamondBalanceWithRetry()
                        }
                    } else {
                    }
                }
            }
        }
    }
}

extension RechargeView {
    // 充值选项网格 - 使用真实的IAP商品
    private var rechargeOptionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 15) {
            // 如果商品已加载，使用真实商品；否则使用默认选项
            if !iapManager.products.isEmpty {
                // 🔧 修复：确保商品按固定顺序显示（已从 IAPManager 排序，这里再次确认）
                ForEach(iapManager.products, id: \.productIdentifier) { product in
                    RechargeOption(
                        title: getTitleForProduct(product.productIdentifier),
                        description: getDescriptionForProduct(product.productIdentifier),
                        price: IAPUtils.formatPrice(product.price, locale: product.priceLocale),
                        diamonds: iapManager.productToDiamonds[product.productIdentifier] ?? 0,
                        isPopular: product.productIdentifier == "NeverSayNo60",
                        isLoading: isProcessing && iapManager.isPurchasing,
                        isDisabled: isProcessing || iapManager.isPurchasing,
                        action: { purchaseProduct(product) }
                    )
                }
            } else {
                // 商品未加载时显示默认选项
                if iapManager.isLoadingProducts {
                    // 正在加载，显示加载状态
                    ForEach(getDefaultRechargeOptions(), id: \.id) { option in
                        RechargeOption(
                            title: option.title,
                            description: option.description,
                            price: option.price,
                            diamonds: option.diamonds,
                            isPopular: option.isPopular,
                            isLoading: true,
                            isDisabled: true,
                            action: {
                                errorMessage = "商品信息正在加载中，请稍候..."
                                showError = true
                            }
                        )
                    }
                } else {
                    // 加载失败或未加载，显示默认选项并提示
                    ForEach(getDefaultRechargeOptions(), id: \.id) { option in
                        RechargeOption(
                            title: option.title,
                            description: option.description,
                            price: option.price,
                            diamonds: option.diamonds,
                            isPopular: option.isPopular,
                            isLoading: false,
                            isDisabled: false,
                            action: {
                                // 如果有错误信息，显示具体错误；否则显示通用提示
                                if let loadError = iapManager.productLoadError {
                                    errorMessage = loadError
                                } else {
                                    errorMessage = "商品信息未加载。请检查网络连接或稍后重试。"
                                }
                                showError = true
                            }
                        )
                    }
                }
            }
        }
    }
    
    // 使用真实的 IAP 购买
    private func purchaseProduct(_ product: SKProduct) {
        
        guard !iapManager.isPurchasing else {
            return
        }
        
        guard SKPaymentQueue.canMakePayments() else {
            errorMessage = "设备不支持支付，请检查您的支付设置"
            showError = true
            return
        }
        
        // 🔧 改进：在购买前检查LeanCloud连接
        // 这样可以防止用户付费后无法同步到服务器的情况
        isProcessing = true
        iapManager.purchaseProduct(product, diamondManager: diamondManager)
    }
    
    // 获取商品标题
    private func getTitleForProduct(_ productId: String) -> String {
        let mapping: [String: String] = [
            "NeverSayNo10": "1元 = 10钻石",
            "NeverSayNo60": "6元 = 60钻石",
            "NeverSayNo500": "48元 = 500钻石",
            "NeverSayNo715": "68元 = 715钻石",
            "NeverSayNo1345": "128元 = 1345钻石",
            "NeverSayNo2100": "198元 = 2100钻石",
            "NeverSayNo3690": "348元 = 3690钻石",
            "NeverSayNo7400": "698元 = 7400钻石"
        ]
        return mapping[productId] ?? "充值"
    }
    
    // 获取商品描述
    private func getDescriptionForProduct(_ productId: String) -> String {
        let mapping: [String: String] = [
            "NeverSayNo10": "新手体验",
            "NeverSayNo60": "基础套餐",
            "NeverSayNo500": "480钻石 + 20钻石",
            "NeverSayNo715": "680钻石 + 35钻石",
            "NeverSayNo1345": "1280钻石 + 65钻石",
            "NeverSayNo2100": "1980钻石 + 120钻石",
            "NeverSayNo3690": "3480钻石 + 210钻石",
            "NeverSayNo7400": "6980钻石 + 420钻石"
        ]
        return mapping[productId] ?? ""
    }
    
    // 获取默认充值选项（硬编码，用于显示灰色禁用状态）
    private func getDefaultRechargeOptions() -> [RechargeOptionData] {
        return [
            RechargeOptionData(id: "diamonds10", title: "1元 = 10钻石", description: "新手体验", price: "¥1", diamonds: 10, isPopular: false),
            RechargeOptionData(id: "diamonds60", title: "6元 = 60钻石", description: "基础套餐", price: "¥6", diamonds: 60, isPopular: true),
            RechargeOptionData(id: "diamonds500", title: "48元 = 500钻石", description: "480钻石 + 20钻石", price: "¥48", diamonds: 500, isPopular: false),
            RechargeOptionData(id: "diamonds715", title: "68元 = 715钻石", description: "680钻石 + 35钻石", price: "¥68", diamonds: 715, isPopular: false),
            RechargeOptionData(id: "diamonds1345", title: "128元 = 1345钻石", description: "1280钻石 + 65钻石", price: "¥128", diamonds: 1345, isPopular: false),
            RechargeOptionData(id: "diamonds2100", title: "198元 = 2100钻石", description: "1980钻石 + 120钻石", price: "¥198", diamonds: 2100, isPopular: false),
            RechargeOptionData(id: "diamonds3690", title: "348元 = 3690钻石", description: "3480钻石 + 210钻石", price: "¥348", diamonds: 3690, isPopular: false),
            RechargeOptionData(id: "diamonds7400", title: "698元 = 7400钻石", description: "6980钻石 + 420钻石", price: "¥698", diamonds: 7400, isPopular: false)
        ]
    }
}

// 充值选项数据模型
struct RechargeOptionData: Identifiable {
    let id: String
    let title: String
    let description: String
    let price: String
    let diamonds: Int
    let isPopular: Bool
}
