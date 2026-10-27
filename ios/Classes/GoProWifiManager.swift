import Foundation
import NetworkExtension
import SystemConfiguration.CaptiveNetwork

@objc class GoProWifiManager: NSObject {
    
    @objc static func connectToWifi(ssid: String, password: String, completion: @escaping (Bool) -> Void) {
        let config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        config.joinOnce = false
        
        NEHotspotConfigurationManager.shared.apply(config) { error in
            if let error = error {
                print("WiFi connection error: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Successfully connected to WiFi: \(ssid)")
                completion(true)
            }
        }
    }
    
    @objc static func disconnectFromWifi(ssid: String, completion: @escaping (Bool) -> Void) {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        completion(true)
    }
    
    @objc static func getCurrentSSID() -> String? {
        var ssid: String?
        if let interfaces = CNCopySupportedInterfaces() as NSArray? {
            for interface in interfaces {
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                    ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
                    break
                }
            }
        }
        return ssid
    }
    
    @objc static func isWifiEnabled() -> Bool {
        // iOS doesn't allow programmatic WiFi enable/disable
        // This is a placeholder that returns true if we can get SSID
        return getCurrentSSID() != nil
    }
}
