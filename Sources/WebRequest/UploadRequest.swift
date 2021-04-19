//
//  UploadRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-28.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
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
        ///   - bodyData: The data to upload
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing   
        public init(_ request: @autoclosure () -> URLRequest,
                    from bodyData: Data,
                    usingSession session: @autoclosure () -> URLSession,
                    completionHandler: ((Results) -> Void)? = nil) {
            var req = request()
            if req.httpMethod == nil ||
               "GET" == req.httpMethod?.uppercased() {
                req.httpMethod = "POST"
            }
            
            let eventDelegate = URLSessionDataTaskEventHandler()
            
            
            let session = URLSession(copy: session(),
                                     delegate: eventDelegate)
            super.init(session.uploadTask(with: req, from: bodyData),
                       eventDelegate: eventDelegate,
                       completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided url and session
        ///
        /// - Parameters:
        ///   - url: The url to request
        ///   - bodyData: The data to upload
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ url: @autoclosure () -> URL,
                                from bodyData: Data,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: ((Results) -> Void)? = nil) {
            self.init(URLRequest(url: url()),
                      from: bodyData,
                      usingSession: session(),
                      completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - fileURL: The file to upload
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public init(_ request: @autoclosure () -> URLRequest,
                    fromFile fileURL: URL,
                    usingSession session: @autoclosure () -> URLSession,
                    completionHandler: ((Results) -> Void)? = nil) {
            var req = request()
            
            if req.httpMethod == nil ||
               "GET" == req.httpMethod?.uppercased() {
                req.httpMethod = "POST"
            }
            let originalSession = session()
            
            let eventDelegate = URLSessionDataTaskEventHandler()
            
            
            let session = URLSession(configuration: originalSession.configuration,
                                     delegate: eventDelegate,
                                     delegateQueue: originalSession.delegateQueue)
            super.init(session.uploadTask(with: req, fromFile: fileURL),
                       eventDelegate: eventDelegate,
                       completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided url and session
        ///
        /// - Parameters:
        ///   - url: The url to request
        ///   - fileURL: The file to upload
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ url: @autoclosure () -> URL,
                                fromFile fileURL: URL,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: ((Results) -> Void)? = nil) {
            self.init(URLRequest(url: url()),
                      fromFile: fileURL,
                      usingSession: session(),
                      completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute with the upload stream
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public init(withStreamedRequest request: URLRequest,
                    usingSession session: @autoclosure () -> URLSession) {
            let originalSession = session()
            
            let eventDelegate = URLSessionDataTaskEventHandler()
            
            
            let session = URLSession(configuration: originalSession.configuration,
                                     delegate: eventDelegate,
                                     delegateQueue: originalSession.delegateQueue)
            super.init(session.uploadTask(withStreamedRequest: request),
                       eventDelegate: eventDelegate)
        }
    }
}
