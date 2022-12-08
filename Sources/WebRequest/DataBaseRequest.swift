//
//  DataBaseRequest.swift
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
    /// Allows for a single data web request
    class DataBaseRequest: TaskedWebRequest<Data> {
        
        internal class URLSessionDataTaskEventHandler: URLSessionTaskEventHandlerWithCompletionHandler<Data>,
                                                       URLSessionDataDelegate {
            
            
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
                    if var workingData = self.taskResults[dataTask.taskIdentifier] {
                        workingData.append(data)
                        self.taskResults[dataTask.taskIdentifier] = workingData
                    } else {
                        self.taskResults[dataTask.taskIdentifier] = data
                    }
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
        ///   - name: Custom Name identifing this request
        ///   - session: The session used to create the task to be invalidated
        ///   - eventDelegate: The delegate used to monitor the task events
        ///   - completionHandler: The call back when done executing
        internal init(_ task: URLSessionDataTask,
                      name: String? = nil,
                      session: URLSession?,
                      eventDelegate: URLSessionDataTaskEventHandler,
                      completionHandler: ((Results) -> Void)? = nil) {
            //print("Creating DataBaseRequest")
            super.init(task,
                       name: name,
                       session: session,
                       eventDelegate: eventDelegate,
                       completionHandler: completionHandler)
        }
        
        
        
        /// Add event handler
        @discardableResult
        public func addDidReceiveDataHandler(_ handler: @escaping (URLSession, DataBaseRequest, Data) -> Void) -> String {
            return self.dataEventDelegate.addDidReceiveDataHandler { [weak self] session, _, data in
                guard let currentSelf = self else { return }
                handler(session, currentSelf, data)
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
            self._results?.emptyData()
            self._results = nil
        }
    }
}
