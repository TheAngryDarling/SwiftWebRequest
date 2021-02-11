//
//  URLSession+WebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-02-10.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif

internal extension URLSession {
    /// Copy a URLSsesion's configuration and delegateQueue while using the given delegate
    convenience init(copy session: URLSession, delegate: URLSessionDelegate?) {
        self.init(configuration: session.configuration,
                   delegate: delegate,
                   delegateQueue: session.delegateQueue)
    }
}
