//
//  LeanCloudService+DataFetch.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation

// MARK: - 数据读取相关方法
extension LeanCloudService {
    
    // 读取LeanCloud中指定表的所有内容
    func fetchAllDataFromTable(tableName: String, completion: @escaping ([[String: Any]]?, String?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/\(tableName)?order=-createdAt&limit=1000"
        guard let url = URL(string: urlString) else {
            completion(nil, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 15.0
        
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, "获取失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    
                    if httpResponse.statusCode == 200, let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]] {
                                completion(results, nil)
                            } else {
                                completion([], nil)
                            }
                        } catch {
                            completion(nil, "数据解析失败: \(error.localizedDescription)")
                        }
                    } else {
                        var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                errorMessage = "服务器错误: \(httpResponse.statusCode)"
                            }
                        }
                        completion(nil, errorMessage)
                    }
                } else {
                    completion(nil, "无效的服务器响应")
                }
            }
        }.resume()
    }
    
    // 读取LeanCloud中所有表的内容
    func fetchAllDataFromAllTables(completion: @escaping ([String: [[String: Any]]]?, String?) -> Void) {
        let tables = ["LocationRecord", "DiamondRecord", "Blacklist", "ReportRecord", "AccountDeletionRequest"]
        var allData: [String: [[String: Any]]] = [:]
        let group = DispatchGroup()
        var hasError = false
        var errorMessage = ""
        
        
        for tableName in tables {
            group.enter()
            fetchAllDataFromTable(tableName: tableName) { data, error in
                if let error = error {
                    hasError = true
                    errorMessage = "\(tableName) 表读取失败: \(error)"
                } else if let data = data {
                    allData[tableName] = data
                } else {
                    allData[tableName] = []
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if hasError {
                completion(nil, errorMessage)
            } else {
                for (_, _) in allData {
                }
                completion(allData, nil)
            }
        }
    }
    
    // 打印指定表的详细数据
    func printTableData(tableName: String, data: [[String: Any]]) {
        
        for (index, record) in data.enumerated() {
            
            // 按字段名排序，让输出更有序
            let sortedKeys = record.keys.sorted()
            for key in sortedKeys {
                _ = record[key] ?? "nil"
            }
            
            if index < data.count - 1 {
            }
        }
    }
    
    // 打印所有表的汇总信息
    func printAllTablesSummary(allData: [String: [[String: Any]]]) {
        
        var totalRecords = 0
        for (_, data) in allData {
            totalRecords += data.count
            
            if !data.isEmpty {
                // 显示第一条记录的字段
                let firstRecord = data[0]
                _ = Array(firstRecord.keys).sorted()
                
                // 显示一些示例数据
                for (_, _) in firstRecord.prefix(8) {
                }
                if firstRecord.count > 8 {
                }
            } else {
            }
            }
    
}
}
