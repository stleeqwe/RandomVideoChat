import UIKit
import Foundation

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCache: URLCache
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let cacheQueue = DispatchQueue(label: "image.cache.queue", qos: .utility)
    
    private init() {
        // 메모리 캐시 설정
        memoryCache.countLimit = 100  // 최대 100개 이미지
        memoryCache.totalCostLimit = 100 * 1024 * 1024  // 100MB
        memoryCache.name = "ImageMemoryCache"
        
        // 디스크 캐시 설정
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")
        
        diskCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20MB
            diskCapacity: 100 * 1024 * 1024,   // 100MB
            directory: cacheDirectory
        )
        
        // 캐시 디렉토리 생성
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 오래된 캐시 자동 정리
        setupCacheCleanup()
        
        // 메모리 경고 시 캐시 정리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func clearMemoryCache() {
        print("🧹 Memory warning received - clearing image cache")
        memoryCache.removeAllObjects()
    }
    
    // MARK: - Public Methods
    func cacheImage(_ image: UIImage, forKey key: String) {
        let cacheKey = NSString(string: key)
        let imageCost = image.jpegData(compressionQuality: 0.8)?.count ?? 0
        
        // 메모리 캐시
        memoryCache.setObject(image, forKey: cacheKey, cost: imageCost)
        
        // 디스크 캐시 (백그라운드)
        cacheQueue.async { [weak self] in
            self?.saveToDisk(image: image, key: key)
        }
    }
    
    func getImage(forKey key: String, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = NSString(string: key)
        
        // 1. 메모리 캐시 확인
        if let cachedImage = memoryCache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
        // 2. 디스크 캐시 확인 (백그라운드)
        cacheQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let image = self.loadFromDisk(key: key)
            
            DispatchQueue.main.async {
                if let image = image {
                    // 메모리 캐시에 다시 저장
                    let imageCost = image.jpegData(compressionQuality: 0.8)?.count ?? 0
                    self.memoryCache.setObject(image, forKey: cacheKey, cost: imageCost)
                }
                completion(image)
            }
        }
    }
    
    func getImage(forKey key: String) -> UIImage? {
        let cacheKey = NSString(string: key)
        
        // 메모리 캐시에서만 동기 조회
        return memoryCache.object(forKey: cacheKey)
    }
    
    func removeImage(forKey key: String) {
        let cacheKey = NSString(string: key)
        memoryCache.removeObject(forKey: cacheKey)
        
        cacheQueue.async { [weak self] in
            self?.removeFromDisk(key: key)
        }
    }
    
    func clearAllCache() {
        memoryCache.removeAllObjects()
        
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    func getCacheSize() -> (memory: Int, disk: Int) {
        let memorySize = memoryCache.totalCostLimit
        let diskSize = getDiskCacheSize()
        return (memorySize, diskSize)
    }
    
    // MARK: - Private Disk Operations
    private func saveToDisk(image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? key
        let fileURL = cacheDirectory.appendingPathComponent(encodedKey)
        
        do {
            try data.write(to: fileURL)
            
            // 파일 속성 설정 (생성일자 등)
            try fileManager.setAttributes([
                .creationDate: Date()
            ], ofItemAtPath: fileURL.path)
            
        } catch {
            print("❌ Failed to save image to disk: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? key
        let fileURL = cacheDirectory.appendingPathComponent(encodedKey)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    private func removeFromDisk(key: String) {
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? key
        let fileURL = cacheDirectory.appendingPathComponent(encodedKey)
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func getDiskCacheSize() -> Int {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        return files.reduce(0) { totalSize, fileURL in
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return totalSize + fileSize
        }
    }
    
    private func setupCacheCleanup() {
        // 앱 시작 시 한 번 정리
        cacheQueue.async { [weak self] in
            self?.cleanOldCache()
        }
        
        // 주기적으로 정리 (매일)
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.cacheQueue.async {
                self?.cleanOldCache()
            }
        }
    }
    
    private func cleanOldCache() {
        let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)  // 7일
        var cleanedCount = 0
        var totalSize = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
            )
            
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                
                if let creationDate = attributes.creationDate,
                   creationDate < expirationDate {
                    try fileManager.removeItem(at: file)
                    cleanedCount += 1
                } else {
                    totalSize += attributes.fileSize ?? 0
                }
            }
            
            print("🧹 Cache cleanup completed: \(cleanedCount) files removed, \(totalSize / 1024 / 1024)MB remaining")
            
        } catch {
            print("❌ 캐시 정리 실패: \(error)")
        }
    }
}