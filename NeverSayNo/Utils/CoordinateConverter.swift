//
//  CoordinateConverter.swift
//  NeverSayNo
//
//  坐标转换工具：WGS-84 <-> GCJ-02
//
//  ⚖️ 法律说明：
//  根据《中华人民共和国测绘法》第四十二条规定：
//  "互联网地图服务提供者应当使用经依法审核批准的地理信息，不得使用未经审核批准的地理信息。"
//
//  中国法律要求：
//  1. 禁止在中国境内直接使用 WGS-84 坐标系（国际标准GPS坐标）进行地图服务
//  2. 必须使用 GCJ-02 坐标系（国测局坐标系/火星坐标系）
//  3. 所有涉及位置显示、存储、传输的操作都必须使用 GCJ-02 坐标系
//
//  技术背景：
//  - WGS-84: World Geodetic System 1984，国际标准，iOS CoreLocation 返回的坐标系
//  - GCJ-02: GuoCeJu-02，中国国家测绘局制定的加密坐标系，俗称"火星坐标系"
//  - GCJ-02 是在 WGS-84 基础上进行非线性加密，无法通过简单的公式完美反推
//
//  使用场景：
//  - 从 iOS CoreLocation 获取的坐标 → 转换为 GCJ-02 → 存储到数据库
//  - 从 iOS CoreLocation 获取的坐标 → 转换为 GCJ-02 → 显示在地图上
//  - 从 iOS CoreLocation 获取的坐标 → 转换为 GCJ-02 → 传输到服务器
//
//  ⚠️ 重要提示：
//  本文件是确保应用符合中国法律的核心组件，任何修改都必须谨慎进行！
//

import Foundation
import CoreLocation

class CoordinateConverter {
    
    // 常量定义（基于 WGS-84 椭球体参数）
    private static let a: Double = 6378245.0  // 长半轴（单位：米）
    private static let ee: Double = 0.00669342162296594323  // 偏心率平方
    
    /// WGS-84 转 GCJ-02（GPS坐标 转 火星坐标）
    /// - Parameters:
    ///   - latitude: WGS-84 纬度
    ///   - longitude: WGS-84 经度
    /// - Returns: GCJ-02 坐标 (纬度, 经度)
    /// - Note: 这是最常用的转换方法，从 iOS CoreLocation 获取坐标后必须调用此方法
    static func wgs84ToGcj02(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        // 判断是否在中国境外，如果在境外则不做转换
        if isOutOfChina(latitude: latitude, longitude: longitude) {
            return (latitude, longitude)
        }
        
        var dLat = transformLatitude(x: longitude - 105.0, y: latitude - 35.0)
        var dLon = transformLongitude(x: longitude - 105.0, y: latitude - 35.0)
        
        let radLat = latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)
        
        let mgLat = latitude + dLat
        let mgLon = longitude + dLon
        
        return (mgLat, mgLon)
    }
    
    /// GCJ-02 转 WGS-84（火星坐标 转 GPS坐标）
    /// - Parameters:
    ///   - latitude: GCJ-02 纬度
    ///   - longitude: GCJ-02 经度
    /// - Returns: WGS-84 坐标 (纬度, 经度)
    /// - Warning: 此方法使用近似算法，存在小误差（约1-2米），因为 GCJ-02 加密算法不可逆
    /// - Note: 一般不需要使用此方法，除非需要将存储的 GCJ-02 坐标转回 WGS-84 用于特殊计算
    static func gcj02ToWgs84(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        // 判断是否在中国境外
        if isOutOfChina(latitude: latitude, longitude: longitude) {
            return (latitude, longitude)
        }
        
        let (mgLat, mgLon) = wgs84ToGcj02(latitude: latitude, longitude: longitude)
        
        return (latitude * 2 - mgLat, longitude * 2 - mgLon)
    }
    
    /// 判断是否在中国境外
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: true 表示在中国境外，false 表示在中国境内
    /// - Note: 这个判断是为了性能优化，中国境外的坐标不需要进行 GCJ-02 转换
    ///
    /// 判断方法：使用矩形边界框快速判断
    /// - 经度范围：72.004°E - 137.8347°E（覆盖中国最西部新疆到最东部黑龙江）
    /// - 纬度范围：0.8293°N - 55.8271°N（覆盖中国最南部南海诸岛到最北部漠河）
    ///
    /// 具体边界说明：
    /// - 西边界（72.004°E）：新疆帕米尔高原西端
    /// - 东边界（137.8347°E）：黑龙江与乌苏里江交汇处
    /// - 南边界（0.8293°N）：南海最南端曾母暗沙
    /// - 北边界（55.8271°N）：黑龙江省漠河县北端
    ///
    /// ⚠️ 注意：
    /// 1. 这是一个粗略的矩形边界判断，不是精确的国界线
    /// 2. 会包含部分邻国领土（如蒙古国、缅甸北部等在矩形内）
    /// 3. 但这是合理的，因为 GCJ-02 转换对这些区域无害，只是增加极小的计算开销
    /// 4. 对于中国境外的大部分国家和地区，可以快速跳过转换，提高性能
    private static func isOutOfChina(latitude: Double, longitude: Double) -> Bool {
        // 判断经度：小于最西端或大于最东端
        if longitude < 72.004 || longitude > 137.8347 {
            return true  // 在中国经度范围之外
        }
        // 判断纬度：小于最南端或大于最北端
        if latitude < 0.8293 || latitude > 55.8271 {
            return true  // 在中国纬度范围之外
        }
        // 在矩形边界框内，视为中国境内
        return false
    }
    
    /// 纬度转换（GCJ-02 加密算法的核心函数之一）
    /// - Parameters:
    ///   - x: 经度差值（longitude - 105.0）
    ///   - y: 纬度差值（latitude - 35.0）
    /// - Returns: 纬度偏移量
    /// - Note: 这是 GCJ-02 加密算法的一部分，参数和公式由国家测绘局制定
    private static func transformLatitude(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    /// 经度转换（GCJ-02 加密算法的核心函数之一）
    /// - Parameters:
    ///   - x: 经度差值（longitude - 105.0）
    ///   - y: 纬度差值（latitude - 35.0）
    /// - Returns: 经度偏移量
    /// - Note: 这是 GCJ-02 加密算法的一部分，参数和公式由国家测绘局制定
    private static func transformLongitude(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}

