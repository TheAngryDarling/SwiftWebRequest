//
//  DataRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-26.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif


public extension WebRequest {
    /// Allows for a single data web request
    class DataRequest: DataBaseRequest {
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public init(_ request: @autoclosure () -> URLRequest,
                    usingSession session: @autoclosure () -> URLSession,
                    completionHandler: ((Results) -> Void)? = nil) {
            
            //print("Creating DataRequest")
            let req = request()
            let originalSession = session()
            
            let eventDelegate = URLSessionDataTaskEventHandler()
            
            
            let session = URLSession(configuration: originalSession.configuration,
                                     delegate: eventDelegate,
                                     delegateQueue: originalSession.delegateQueue)
            super.init(session.dataTask(with: req),
                       eventDelegate: eventDelegate,
                       originalRequest: req,
                       completionHandler: completionHandler)
            
        }
        
        /// Create a new WebRequest using the provided url and session
        ///
        /// - Parameters:
        ///   - url: The url to request
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ url: @autoclosure () -> URL,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: ((Results) -> Void)? = nil) {
            self.init(URLRequest(url: url()),
                      usingSession: session(),
                      completionHandler: completionHandler)
        }
    }
}
