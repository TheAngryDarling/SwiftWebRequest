//
//  DataRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-26.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
#endif


public extension WebRequest {
    /// Allows for a single data web request
    class DataRequest: DataBaseRequest {
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// This init is intended for the RepeatDataRequest to use a single
        /// event delegate for each request
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - name: Custom Name identifing this request
        ///   - session: The URL Session to use
        ///   - eventDelegate: The Event Delegate used with the session
        ///   - completionHandler: The call back when done executing
        internal init(_ request: @autoclosure () -> URLRequest,
                      name: String? = nil,
                      usingSession session: URLSession,
                      eventDelegate: URLSessionDataTaskEventHandler,
                      completionHandler: ((Results) -> Void)? = nil) {
            super.init(session.dataTask(with: request()),
                       name: name,
                       session: session,
                       invalidateSession: false,
                       proxyDelegateId: nil,
                       eventDelegate: eventDelegate,
                       completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - name: Custom Name identifing this request
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public init(_ request: @autoclosure () -> URLRequest,
                    name: String? = nil,
                    usingSession session: @autoclosure () -> URLSession,
                    completionHandler: ((Results) -> Void)? = nil) {
            
            let eventDelegate: URLSessionDataTaskEventHandler = URLSessionDataTaskEventHandler()
            var workingSession: URLSession = session()
            var invalidateSession: Bool = false
            var proxyDelegateId: String? = nil
            
            
            if let proxyDelegate = workingSession.delegate as? WebRequestSharedSessionDelegate {
                proxyDelegateId = proxyDelegate.pushChildDelegate(delegate: eventDelegate)
                invalidateSession = false
            } else {
                proxyDelegateId = nil
                
                workingSession = URLSession(copy: workingSession,
                                            delegate: eventDelegate)
                invalidateSession = true
            }
            
            super.init(workingSession.dataTask(with: request()),
                       name: name,
                       session: workingSession,
                       invalidateSession: invalidateSession,
                       proxyDelegateId: proxyDelegateId,
                       eventDelegate: eventDelegate,
                       completionHandler: completionHandler)
            
            
        }
        
        /// Create a new WebRequest using the provided url and session
        ///
        /// - Parameters:
        ///   - url: The url to request
        ///   - name: Custom Name identifing this request   
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ url: @autoclosure () -> URL,
                                name: String? = nil,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: ((Results) -> Void)? = nil) {
            self.init(URLRequest(url: url()),
                      name: name,
                      usingSession: session(),
                      completionHandler: completionHandler)
        }
    }
}
