//
//  BonjourService.swift
//  bonjourTest
//
//  Created by Pratyush on 18/01/19.
//

import Foundation

class BonjourService: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    var timeout: TimeInterval = 2.0
    var serviceFoundClosure: (([NetService]) -> Void)!
    
    struct Services {
        // Used by Personal Web Sharing in the Sharing preference panel to advertise the User's
        // Sites folders starting in Mac OS X 10.2.4. Safari can be used to browse for web servers.
        static let Hypertext_Transfer: String = "_http._tcp."
    }
    static let LocalDomain: String = "local."
    
    let serviceBrowser: NetServiceBrowser = NetServiceBrowser()
    var services = [NetService]()
    var isSearching: Bool = false
    var serviceTimeout: Timer = Timer()
    
    /// Find all services matching the given identifer in the given domain
    ///
    /// Calls servicesFound: with any services found
    /// If no services were found, servicesFound: is called with an empty array
    ///
    /// **Note:** Only one search can run at a time.
    ///
    /// - parameters:
    ///   - identifier: The service identifier. You may use BonjourService.Services for common services
    ///   - domain: The domain name for the service.  You may use BonjourService.LocalDomain
    /// - returns: True if the search was started, false if a search is already running
    func findService(_ identifier: String, domain: String, found: @escaping ([NetService]) -> Void) -> Bool {
        if !isSearching {
            serviceBrowser.delegate = self
            serviceTimeout = Timer.scheduledTimer(
                timeInterval: self.timeout,
                target: self,
                selector: #selector(BonjourService.noServicesFound),
                userInfo: nil,
                repeats: false)
            serviceBrowser.searchForServices(ofType: identifier, inDomain: domain)
            serviceFoundClosure = found
            isSearching = true
            return true
        }
        return false
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService,
                           moreComing: Bool) {
        serviceTimeout.invalidate()
        services.append(service)
        if !moreComing {
            serviceFoundClosure(services)
            serviceBrowser.stop()
            isSearching = false
//            for svc in services {
//                if svc.name.lowercased().contains("barsys") {
//                    svc.delegate = self
//                    svc.resolve(withTimeout: 5)
//                }
//            }
        }
    }
    
    @objc func noServicesFound() {
        serviceFoundClosure([])
        serviceBrowser.stop()
        isSearching = false
    }
    
    let info = ProcessInfo.processInfo
    var begin: TimeInterval = TimeInterval()
    
    func resolveService(service: NetService) {
        service.delegate = self
        begin = info.systemUptime
        service.resolve(withTimeout: 0.0)
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("didNotResolve")
    }
    
    func netServiceDidStop(_ sender: NetService) {
        print("netServiceDidStop")
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        print("Elapsed time - \((info.systemUptime - begin))")
        print("Resolved - \(sender.name)")
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard let data = sender.addresses?.first else { return }
        data.withUnsafeBytes { (pointer:UnsafePointer<sockaddr>) -> Void in
            guard getnameinfo(pointer, socklen_t(data.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 else {
                return
            }
        }
        let ipAddress = String(cString:hostname)
        print(ipAddress)
        sender.startMonitoring()
//        sender.getInputStream(<#T##inputStream: UnsafeMutablePointer<InputStream?>?##UnsafeMutablePointer<InputStream?>?#>, outputStream: <#T##UnsafeMutablePointer<OutputStream?>?#>)
    }
    
    var svc = NetService()
    
    func publishService(port: Int32) {
        svc = NetService(domain: "local", type: "_http._tcp.", name: "BarsysDummy", port: port)
        svc.delegate = self
        svc.publish()
    }
    
    func netServiceDidPublish(_ sender: NetService) {
        print("\(svc.name) running on port \(svc.port)")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print(errorDict)
    }
}
