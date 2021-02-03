//
//  DataBaseRequest.swift
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
    /// Allows for a single data web request
    class DataBaseRequest: TaskedWebRequest<Data> {
        
        public typealias Results = TaskedWebResults<Data>
        
        internal class URLSessionDataTaskEventHandler: URLSessionTaskEventHandlerWithCompletionHandler<Data>,
                                                       URLSessionDataDelegate {
            
            
            override func urlSession(_ session: URLSession,
                                     task: URLSessionTask,
                                     didCompleteWithError error: Error?) {
               super.urlSession(session, task: task, didCompleteWithError: error)
                self.results = nil
            }
            
            
            
            public private(set) var didReceiveDataHandler: [String: (URLSession, URLSessionDataTask, Data) -> Void] = [:]
            
            /// Add event handler
            @discardableResult
            public func addDidReceiveDataHandler(withId uid: String,
                                                 _ handler: @escaping (URLSession, URLSessionDataTask, Data) -> Void) -> String {
                precondition(!self.didReceiveDataHandler.keys.contains(uid), "Id already in use")
                self.didReceiveDataHandler[uid] = handler
                self.hasEventHandlers = true
                return uid
            }
            
            /// Add event handler
            @discardableResult
            public func addDidReceiveDataHandler(_ handler: @escaping (URLSession, URLSessionDataTask, Data) -> Void) -> String {
                return self.addDidReceiveDataHandler(withId: UUID().uuidString, handler)
            }
            /// Remove event handler with the given Id
            public func removeDidReceiveDataHandler(withId id: String) {
                self.didReceiveDataHandler.removeValue(forKey: id)
            }
            
            
            
            func urlSession(_ session: URLSession,
                            dataTask: URLSessionDataTask,
                            didReceive data: Data) {
                
                if self.completionHandler.count > 0 || !self.hasEventHandlers {
                    if self.results == nil { self.results = Data() }
                    self.results?.append(data)
                }
                
                for (_, handler) in self.didReceiveDataHandler {
                    handler(session, dataTask, data)
                }
            }
            
            override func removeHandlers(withId uid: String) {
                self.didReceiveDataHandler.removeValue(forKey: uid)
                super.removeHandlers(withId: uid)
            }
        }
        
        
        
        internal var dataEventDelegate: URLSessionDataTaskEventHandler {
            return self.eventDelegate as! URLSessionDataTaskEventHandler
        }
        
        
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - task: The task executing the request
        ///   - eventDelegate: The delegate used to monitor the task events
        ///   - originalRequest: The original request of the task
        ///   - completionHandler: The call back when done executing
        internal init(_ task: URLSessionDataTask,
                      eventDelegate: URLSessionDataTaskEventHandler,
                      originalRequest: URLRequest,
                      completionHandler: ((Results) -> Void)? = nil) {
            //print("Creating DataBaseRequest")
            super.init(task,
                       eventDelegate: eventDelegate,
                       originalRequest: originalRequest,
                       completionHandler: completionHandler)
        }
        
        
        
        /// Add event handler
        @discardableResult
        public func addDidReceiveDataHandler(_ handler: @escaping (URLSession, DataBaseRequest, Data) -> Void) -> String {
            return self.dataEventDelegate.addDidReceiveDataHandler { [weak self] session, _, data in
                guard self != nil else { return }
                handler(session, self!, data)
            }
        }
        /// Remove event handler with the given Id
        public func removeDidReceiveDataHandler(withId id: String) {
            self.dataEventDelegate.removeDidReceiveDataHandler(withId: id)
        }
        
        /// Allows for clearing of the reponse data.
        /// This can be handy when working with GroupRequests with a lot of data.
        /// That way you can process each request as it comes in and clear the data so its not sitting in memeory until all requests are finished
        public func emptyResultsData() {
            self.results.emptyData()
        }
    }
}
