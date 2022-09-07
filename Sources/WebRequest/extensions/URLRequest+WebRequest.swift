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
        self = oldRequest
        self.url = url
    }
}
