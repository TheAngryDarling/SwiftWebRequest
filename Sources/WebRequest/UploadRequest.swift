//
//  UploadRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-28.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
#endif

public extension WebRequest {
    /// Allows for a single upload web request
    class UploadRequest: DataBaseRequest {
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - name: Custom Name identifing this request
        ///   - bodyData: The data to upload
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing   
        public init(_ request: @autoclosure () -> URLRequest,
                    name: String? = nil,
                    from bodyData: Data,
                    usingSession session: @autoclosure () -> URLSession,
                    completionHandler: ((Results) -> Void)? = nil) {
            var req = request()
            if req._httpMethod == nil ||
                req._httpMethod == .get {
                req._httpMethod = .post
            }
            
            let currentSession = session()
            let eventDelegate = URLSessionDataTaskEventHandler()
            var workingSession: URLSession
            var invalidateSession: Bool
            let proxyDelegateId: String?
            
            if let proxyDelegate = currentSession.delegate as? WebRequestSharedSessionDelegate {
                proxyDelegateId = proxyDelegate.pushChildDelegate(delegate: eventDelegate)
                workingSession = currentSession
                invalidateSession = false
            } else {
                proxyDelegateId = nil
                workingSession = URLSession(copy: currentSession,
                                            delegate: eventDelegate)
                invalidateSession = true
            }
            
            
            super.init(workingSession.dataTask(with: req),
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
        ///   - bodyData: The data to upload
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ url: @autoclosure () -> URL,
                                name: String? = nil,
                                from bodyData: Data,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: ((Results) -> Void)? = nil) {
            self.init(URLRequest(url: url()),
                      name: name,
                      from: bodyData,
                      usingSession: session(),
                      completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - name: Custom Name identifing this request
        ///   - fileURL: The file to upload
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public init(_ request: @autoclosure () -> URLRequest,
                    name: String? = nil,
                    fromFile fileURL: URL,
                    usingSession session: @autoclosure () -> URLSession,
                    completionHandler: ((Results) -> Void)? = nil) {
            var req = request()
            
            if req._httpMethod == nil ||
                req._httpMethod == .get {
                req._httpMethod = .post
            }
            
            let currentSession = session()
            let eventDelegate = URLSessionDataTaskEventHandler()
            var workingSession: URLSession
            var invalidateSession: Bool
            let proxyDelegateId: String?
            
            if let proxyDelegate = currentSession.delegate as? WebRequestSharedSessionDelegate {
                proxyDelegateId = proxyDelegate.pushChildDelegate(delegate: eventDelegate)
                workingSession = currentSession
                invalidateSession = false
            } else {
                proxyDelegateId = nil
                workingSession = URLSession(copy: currentSession,
                                            delegate: eventDelegate)
                invalidateSession = true
            }
            
            super.init(workingSession.uploadTask(with: req, fromFile: fileURL),
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
        ///   - fileURL: The file to upload
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ url: @autoclosure () -> URL,
                                name: String? = nil,
                                fromFile fileURL: URL,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: ((Results) -> Void)? = nil) {
            self.init(URLRequest(url: url()),
                      name: name,
                      fromFile: fileURL,
                      usingSession: session(),
                      completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute with the upload stream
        ///   - name: Custom Name identifing this request   
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public init(withStreamedRequest request: URLRequest,
                    name: String? = nil,
                    usingSession session: @autoclosure () -> URLSession) {
            
            let currentSession = session()
            let eventDelegate = URLSessionDataTaskEventHandler()
            var workingSession: URLSession
            var invalidateSession: Bool
            let proxyDelegateId: String?
            
            if let proxyDelegate = currentSession.delegate as? WebRequestSharedSessionDelegate {
                proxyDelegateId = proxyDelegate.pushChildDelegate(delegate: eventDelegate)
                workingSession = currentSession
                invalidateSession = false
            } else {
                proxyDelegateId = nil
                workingSession = URLSession(copy: currentSession,
                                            delegate: eventDelegate)
                invalidateSession = true
            }
            
            
            super.init(workingSession.uploadTask(withStreamedRequest: request),
                       name: name,
                       session: workingSession,
                       invalidateSession: invalidateSession,
                       proxyDelegateId: proxyDelegateId,
                       eventDelegate: eventDelegate)
        }
    }
}
#if swift(>=5.7)
extension WebRequest.UploadRequest: @unchecked Sendable { }
#endif
