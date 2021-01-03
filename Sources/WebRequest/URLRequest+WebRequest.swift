//
//  URLRequest+WebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-02.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif

internal extension URLRequest {
    /// Create new URLRequest copying old request details
    init(url: URL,
         _ oldRequest: URLRequest) {
        self.init(url: url,
                  cachePolicy: oldRequest.cachePolicy,
                  timeoutInterval: oldRequest.timeoutInterval)
        
        self.allHTTPHeaderFields = oldRequest.allHTTPHeaderFields
        self.allowsCellularAccess = oldRequest.allowsCellularAccess
        #if _runtime(_ObjC)
            if #available(OSX 10.15, *) {
                self.allowsConstrainedNetworkAccess = oldRequest.allowsConstrainedNetworkAccess
            }
            if #available(OSX 10.15, *) {
                self.allowsExpensiveNetworkAccess = oldRequest.allowsExpensiveNetworkAccess
            }
        #endif
        self.httpBody = oldRequest.httpBody
        self.httpMethod = oldRequest.httpMethod
        self.httpShouldHandleCookies = oldRequest.httpShouldHandleCookies
        self.httpShouldUsePipelining = oldRequest.httpShouldUsePipelining
        self.networkServiceType = oldRequest.networkServiceType
    }
}
