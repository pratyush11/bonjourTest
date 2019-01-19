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
    
    /// Find all servies matching the given identifer in the given domain
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
            for svc in services {
                if svc.name.lowercased().contains("barsys") {
                    svc.resolve(withTimeout: 5)
                }
            }
        }
    }
    
    @objc func noServicesFound() {
        serviceFoundClosure([])
        serviceBrowser.stop()
        isSearching = false
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        print("Resolved - \(sender.name)")
    }
    
}
