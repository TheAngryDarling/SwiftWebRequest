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
            
            /// Flag use to indicate of the results should be saved if not automatically.
            /// This flag must be set to true before starting request to ensure collecting of
            /// the results
            public var forceSaveResults: Bool = false
            
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
                
                // Only accept events for the given request
                guard self.isWorkingTask(dataTask) else { return }
                
                if self.completionHandler.count > 0 ||
                    !self.hasEventHandlers ||
                    self.forceSaveResults {
                    
                    if var workingData = self.results {
                        workingData.append(data)
                        self.results = workingData
                    } else {
                        self.results = data
                    }
                }
                
                for (_, handler) in self.didReceiveDataHandler {
                    if let q = self.eventHandlerQueue {
                        q.sync {
                            WebRequest.autoreleasepool {
                                handler(session, dataTask, data)
                            }
                        }
                    } else {
                        WebRequest.autoreleasepool {
                            handler(session, dataTask, data)
                        }
                    }
                }
            }
            
            override func urlSession(_ session: URLSession,
                                     task: URLSessionTask,
                                     didCompleteWithError error: Error?) {
                // Only accept events for the given request
                guard self.isWorkingTask(task) else { return }
                
                if error == nil && self.results == nil {
                    // If the data request is complete but no data
                    // was returned from the body of the request
                    // then lets set the results as an empty Data structure
                    self.results = Data()
                }
                super.urlSession(session,
                                 task: task,
                                 didCompleteWithError: error)
            }
            
            override func removeHandlers(withId uid: String) {
                self.didReceiveDataHandler.removeValue(forKey: uid)
                super.removeHandlers(withId: uid)
            }
        }
        
        
        
        internal var dataEventDelegate: URLSessionDataTaskEventHandler {
            return self.eventDelegate as! URLSessionDataTaskEventHandler
        }
        
        /// Flag use to indicate of the results should be saved if not automatically.
        /// This flag must be set to true before starting request to ensure collecting of
        /// the results
        public var forceSaveResults: Bool {
            get { return self.dataEventDelegate.forceSaveResults }
            set { self.dataEventDelegate.forceSaveResults = newValue }
        }
        
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - task: The task executing the request
        ///   - name: Custom Name identifing this request
        ///   - session: The session the task was created from
        ///   - invalidateSession: Indicator if the session should be invalidated when deinited
        ///   - proxyDelegateId: The id of the delegate storede wihtin the proxy delegate
        ///   - eventDelegate: The delegate used to monitor the task events
        ///   - completionHandler: The call back when done executing
        internal init(_ task: URLSessionDataTask,
                      name: String? = nil,
                      session: URLSession,
                      invalidateSession: Bool,
                      proxyDelegateId: String?,
                      eventDelegate: URLSessionDataTaskEventHandler,
                      completionHandler: ((Results) -> Void)? = nil) {
            super.init(task,
                       name: name,
                       session: session,
                       invalidateSession: invalidateSession,
                       proxyDelegateId: proxyDelegateId,
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
#if swift(>=5.7)
extension WebRequest.DataBaseRequest: @unchecked Sendable { }
#endif
