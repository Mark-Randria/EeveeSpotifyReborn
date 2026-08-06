import Foundation

/// Streams the encrypted bytes from Spotify's CDN and converts them into a
/// playable audio container via `StreamDecryptor`.
final class SpotifyCDNClient {
    static let shared = SpotifyCDNClient()

    enum CDNError: LocalizedError {
        case httpStatus(Int)
        case moveTempFile(String)

        var errorDescription: String? {
            switch self {
            case .httpStatus(let code):
                return "CDN responded with HTTP \(code)"
            case .moveTempFile(let reason):
                return "Could not stage CDN file: \(reason)"
            }
        }
    }

    private static let audioExtensions: Set<String> = ["mp4", "m4a", "aac", "ogg", "mp3", "opus"]

    private let session: URLSession
    private let fileManager = FileManager.default

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": "EeveeSpotify/1.0 (iOS)",
            "Accept": "audio/mp4, audio/aac, audio/ogg, audio/mpeg, */*;q=0.8"
        ]
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 600
        configuration.waitsForConnectivity = true

        session = URLSession(configuration: configuration)
    }

    /// Downloads the encrypted stream to a temp file (streamed by URLSession),
    /// decrypts it to `outputDirectory`/`fileName.<ext>`, then removes the temp
    /// file. Progress is reported over 0...0.5 for download and 0.5...1.0 for
    /// decryption. The bearer token is deliberately NOT sent here: CDN URLs are
    /// typically signed, so the token is not required.
    func downloadEncryptedStream(
        url: URL,
        key: Data,
        to outputDirectory: URL,
        fileName: String,
        progress: ((Double) -> Void)?
    ) async throws -> URL {
        // 1. Stream encrypted bytes into a staging temp file.
        let stagedURL = fileManager.temporaryDirectory
            .appendingPathComponent("EeveeStream-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: stagedURL) }

        let progressDelegate = DownloadProgressDelegate { written in
            progress?(written * 0.5)
        }

        let (downloadedLocation, response) = try await session.download(from: url, delegate: progressDelegate)

        if let httpResponse = response as? HTTPURLResponse,
            !(200..<300).contains(httpResponse.statusCode) {
            throw CDNError.httpStatus(httpResponse.statusCode)
        }

        do {
            try fileManager.moveItem(at: downloadedLocation, to: stagedURL)
        }
        catch let error {
            throw CDNError.moveTempFile(error.localizedDescription)
        }

        // 2. Decrypt into the final file inside the downloads directory.
        let extensionName = SpotifyCDNClient.audioExtension(for: url)
        let finalURL = outputDirectory
            .appendingPathComponent(fileName, isDirectory: false)
            .appendingPathExtension(extensionName)

        do {
            try StreamDecryptor.decryptStream(
                input: stagedURL,
                output: finalURL,
                key: key,
                progress: { decrypted in
                    progress?(0.5 + decrypted * 0.5)
                }
            )
        }
        catch let error {
            // Never leave a partial file behind in the downloads directory.
            try? fileManager.removeItem(at: finalURL)
            throw error
        }

        return finalURL
    }

    private static func audioExtension(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if audioExtensions.contains(ext) {
            return ext
        }
        return "ogg"
    }
}

/// Receives `URLSessionDownloadTask` progress callbacks while the per-task async
/// download runs (progress is otherwise unavailable on the async API).
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(min(1.0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Not used; the async wrapper returns the file location directly.
    }
}
