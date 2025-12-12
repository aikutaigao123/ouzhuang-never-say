import SwiftUI
import Foundation

struct FileHelpers {
    // 获取文档目录路径
    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // 获取缓存目录路径
    static func getCacheDirectory() -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // 获取临时目录路径
    static func getTemporaryDirectory() -> URL {
        return FileManager.default.temporaryDirectory
    }
    
    // 检查文件是否存在
    static func fileExists(at path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    // 检查文件是否存在（URL版本）
    static func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // 创建目录
    static func createDirectory(at url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }
    
    // 删除文件
    static func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }
    
    // 获取文件大小
    static func getFileSize(at url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    // 获取文件修改时间
    static func getFileModificationDate(at url: URL) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    // 复制文件
    static func copyFile(from sourceURL: URL, to destinationURL: URL) -> Bool {
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return true
        } catch {
            return false
        }
    }
    
    // 移动文件
    static func moveFile(from sourceURL: URL, to destinationURL: URL) -> Bool {
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            return true
        } catch {
            return false
        }
    }
    
    // 获取目录中的所有文件
    static func getFilesInDirectory(at url: URL) -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            return contents.filter { !$0.hasDirectoryPath }
        } catch {
            return []
        }
    }
    
    // 获取目录中的所有子目录
    static func getDirectoriesInDirectory(at url: URL) -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            return contents.filter { $0.hasDirectoryPath }
        } catch {
            return []
        }
    }
    
    // 清理临时文件
    static func cleanupTemporaryFiles() -> Int {
        let tempDir = getTemporaryDirectory()
        let files = getFilesInDirectory(at: tempDir)
        var deletedCount = 0
        
        for file in files {
            if deleteFile(at: file) {
                deletedCount += 1
            }
        }
        
        return deletedCount
    }
    
    // 获取可用磁盘空间
    static func getAvailableDiskSpace() -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return attributes[.systemFreeSize] as? Int64
        } catch {
            return nil
        }
    }
    
    // 格式化文件大小
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // 检查文件是否为图片
    static func isImageFile(at url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
        let fileExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }
    
    // 检查文件是否为视频
    static func isVideoFile(at url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"]
        let fileExtension = url.pathExtension.lowercased()
        return videoExtensions.contains(fileExtension)
    }
    
    // 检查文件是否为音频
    static func isAudioFile(at url: URL) -> Bool {
        let audioExtensions = ["mp3", "wav", "aac", "flac", "ogg", "m4a"]
        let fileExtension = url.pathExtension.lowercased()
        return audioExtensions.contains(fileExtension)
    }
}
