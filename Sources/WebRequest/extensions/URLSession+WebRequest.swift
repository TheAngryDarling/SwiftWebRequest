//
//  URLSession+WebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-02-10.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
#endif

internal extension URLSession {
    /// Copy a URLSsesion's configuration and delegateQueue while using the given delegate
    convenience init(copy session: URLSession,
                     delegate: URLSessionDelegate? = nil,
                     delegateQueue queue: OperationQueue? = nil) {
        
        self.init(configuration: session.configuration,
                  delegate: delegate ?? session.delegate,
                  delegateQueue: queue ?? session.delegateQueue)
    }
}


public extension URLSession {
    
    /// Create a new URLSession wth the WebRequestSharedSessionDelegate
    ///
    /// Using the WebRequestSharedSessionDelegate as the delegate for the URLSession allows
    /// any of the WebRequest objects to share the URLSession and not copie it
    ///
    /// Note: Please remember to invalidate the session when done using to avoid any memory leaks
    ///
    /// - Parameters:
    ///   - config: A configuration object that specifies certain behaviors, such as caching policies, timeouts, proxies, pipelining, TLS versions to support, cookie policies, and credential storage.
    ///   - delegate:A session delegate object that handles requests for authentication and other session-related events.
    ///   - delegateQueue: An operation queue for scheduling the delegate calls and completion handlers. The queue should be a serial queue, in order to ensure the correct ordering of callbacks. If nil, the session creates a serial operation queue for performing all delegate method calls and completion handler calls.
    /// - Returns: Returns the newly created URLSession that has WebRequestSharedSessionDelegate as its delegate
    static func usingWebRequestSharedSessionDelegate(configuration: URLSessionConfiguration = URLSessionConfiguration.default,
                                           delegate: URLSessionDelegate? = nil,
                                           delegateQueue queue: OperationQueue? = nil) -> URLSession {
        let wrsDelegate: WebRequestSharedSessionDelegate
        // if the delegate passed to the function is already
        // a WebRequestSharedSessionDelegate then we wont
        // create a new one, we'll just use it
        if let d = delegate as? WebRequestSharedSessionDelegate {
            wrsDelegate = d
        } else {
            wrsDelegate = WebRequestSharedSessionDelegate()
            if let d = delegate {
                wrsDelegate.appendChildDelegate(delegate: d)
            }
        }
        
        return URLSession(configuration: configuration,
                          delegate: wrsDelegate,
                          delegateQueue: queue)
         
    }
}
