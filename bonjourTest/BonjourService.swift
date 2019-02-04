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
    
    //MARK:- Discovery methods
    
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
    }
    
    var iStream: InputStream?
    var oStream: OutputStream?
    var openedStreams = 0
    var streamsConnected = false
    var streamsConnectedCallback: (() -> Void)?
    var dataReceivedCallback: ((String) -> Void)?
    
    func connectService(service: NetService, callback: (() -> Void)?) {
        self.streamsConnectedCallback = callback
        if !service.getInputStream(&iStream, outputStream: &oStream) {
            print("Could not connect.")
        }
        self.openStreams()
    }
    
    func openStreams() {
        guard self.openedStreams == 0 else {
            return print("streams already opened... \(self.openedStreams)")
        }
        self.iStream?.delegate = self
        self.iStream?.schedule(in: .current, forMode: .defaultRunLoopMode)
        self.iStream?.open()
        
        self.oStream?.delegate = self
        self.oStream?.schedule(in: .current, forMode: .defaultRunLoopMode)
        self.oStream?.open()
    }
    
    func closeStreams() {
        self.iStream?.remove(from: .current, forMode: .defaultRunLoopMode)
        self.iStream?.close()
        self.iStream = nil
        
        self.oStream?.remove(from: .current, forMode: .defaultRunLoopMode)
        self.oStream?.close()
        self.oStream = nil
        
        self.streamsConnected = false
        self.openedStreams = 0
    }

    func send(message: String) {
        guard self.openedStreams == 2 else {
            return print("No open streams: \(self.openedStreams)")
        }
        
        guard self.oStream!.hasSpaceAvailable else {
            return print("No space available.")
        }
        
        let data = message.data(using: .utf8)!
        
        let bytesWritten = data.withUnsafeBytes { self.oStream?.write($0, maxLength: data.count) }
        
        guard bytesWritten == data.count else {
            self.closeStreams()
            print("Something is wrong.")
            return
        }
        print("Data written: \(message)")
    }

    
    //MARK:- Publish methods
    
    var svc = NetService()
    
    func publishService(port: Int32) {
        precondition(port >= -1 && port <= 65535, "Port should be in the range 0-65535")
        svc = NetService(domain: "local.", type: Services.Hypertext_Transfer, name: "TestService", port: port)
        svc.delegate = self
        svc.includesPeerToPeer = true
        svc.publish(options: .listenForConnections)
        svc.schedule(in: .current, forMode: .defaultRunLoopMode)
    }
    
    func netServiceWillPublish(_ sender: NetService) {
        print("\(svc) will publish.")
    }
    
    func netServiceDidPublish(_ sender: NetService) {
        print("\(svc.name) running on port \(svc.port)")
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        print(errorDict)
    }
}

extension BonjourService: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if eventCode.contains(.openCompleted) {
            self.openedStreams += 1
        }
        if eventCode.contains(.hasSpaceAvailable) {
            if self.openedStreams == 2 && !self.streamsConnected {
                print("streams connected.")
                self.streamsConnected = true
                self.streamsConnectedCallback?()
            }
        }
        if eventCode.contains(.hasBytesAvailable) {
            guard let inputStream = self.iStream else {
                return print("no input stream")
            }
            
            let bufferSize     = 4096
            var buffer         = Array<UInt8>(repeating: 0, count: bufferSize)
            var message        = ""
            
            while inputStream.hasBytesAvailable {
                let len = inputStream.read(&buffer, maxLength: bufferSize)
                if len < 0 {
                    print("error reading stream...")
                    return self.closeStreams()
                }
                if len > 0 {
                    message += String(bytes: buffer, encoding: .utf8)!
                }
                if len == 0 {
                    print("no more bytes available...")
                    break
                }
            }
            self.dataReceivedCallback?(message)
        }
    }
}
