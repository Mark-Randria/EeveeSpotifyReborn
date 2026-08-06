import Foundation

extension URL {
    var isLyrics: Bool {
        self.path.contains("color-lyrics/v2")
    }
    
    var isPlanOverview: Bool {
        self.path.contains("GetPlanOverview")
    }
    
    var isPremiumPlanRow: Bool {
        self.path.contains("v1/GetPremiumPlanRow")
    }
    
    var isPremiumBadge: Bool {
        self.path.contains("GetYourPremiumBadge")
    }

    var isOpenSpotifySafariExtension: Bool {
        self.host == "eevee"
    }
    
    var isCustomize: Bool {
        self.path.contains("v1/customize")
    }
    
    var isBootstrap: Bool {
        self.path.contains("v1/bootstrap")
    }
    
    // MARK: - EeveeDownload spike predicates
    
    /// Broad heuristic for CDN audio stream URLs (SPIKE: keep it loose).
    var isAudioStreamURL: Bool {
        guard let host = self.host?.lowercased() else {
            return false
        }
        
        if host.contains("scdn") {
            return true
        }
        if host.hasPrefix("audio-") {
            return true
        }
        if host.hasSuffix(".audio.spotify.com") {
            return true
        }
        if self.path.contains("/audio/") {
            return true
        }
        
        let pathExtension = self.pathExtension.lowercased()
        let spotifyHost = host.contains("spotify")
            || host.contains("akamaized")
            || host.contains("cloudfront")
        
        return spotifyHost && ["mp4", "aac", "ogg", "mp3"].contains(pathExtension)
    }
    
    /// Broad heuristic for the per-track AES audio key exchange endpoint.
    var isAudioKeyExchangeURL: Bool {
        let path = self.path.lowercased()
        return path.contains("track-urn")
            || path.contains("audio-key")
            || path.contains("key-exchange")
            || path.contains("crypt")
            || path.contains("widevine")
    }
    
    /// Spotify API hosts we expect to carry the OAuth bearer token.
    var isSpotifyAPIURL: Bool {
        guard let host = self.host else {
            return false
        }
        return host == "api.spotify.com"
            || host == "spclient.wg.spotify.com"
            || host == "gew1-spclient.spotify.com"
            || host.hasSuffix("spclient.wg.spotify.com")
    }
}
