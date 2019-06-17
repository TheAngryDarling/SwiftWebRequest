//
//  GroupWebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2018-06-06.
//

import Foundation
import Dispatch

public extension WebRequest {
    /// GroupWebRequest allows for excuting multiple WebRequests at the same time
    public class GroupRequest: WebRequest {
        
        enum Error: Swift.Error {
            case errors([Swift.Error])
        }
        
        /// Event handler for when one of the child requests has started
        public var singleRequestStarted: ((GroupRequest, Int, WebRequest) -> Void)? = nil
        /// Event handler for when one of the child requests has resumed
        public var singleRequestResumed: ((GroupRequest, Int, WebRequest) -> Void)? = nil
        /// Event handler for when one of the child requests hsa been suspended
        public var singleRequestSuspended: ((GroupRequest, Int, WebRequest) -> Void)? = nil
        /// Event handler for when one of the child requests has been cancelled
        public var singleRequestCancelled: ((GroupRequest, Int, WebRequest) -> Void)? = nil
        /// Event handler for when on of the child reuquests has completed
        public var singleRequestCompleted: ((GroupRequest, Int, WebRequest) -> Void)? = nil
        /// Event handler for when one of the child requests state has changed
        public var singleRequestStateChanged: ((GroupRequest, Int, WebRequest, WebRequest.State) -> Void)? = nil
        
        private var completionHandler: (([WebRequest]) -> Void)? = nil
        private let completionHandlerLockingQueue: DispatchQueue = DispatchQueue(label: "org.webrequest.WebRequest.CompletionHandler.Locking")
        private var hasCalledCompletionHandler: Bool = false
        
        private var operationQueue: OperationQueue = OperationQueue()
        public var maxConcurrentRequestCount: Int {
            get { return self.operationQueue.maxConcurrentOperationCount }
            set { self.operationQueue.maxConcurrentOperationCount = newValue }
        }
        /// array of child web requsts
        public let requests: [WebRequest]
        private var requestsFinished: [Bool]
        private var suspendedRequests: [Int] = []
        
        private var hasBeenCancelled: Bool = false
        
        
        #if os(macOS) && os(iOS) && os(tvOS) && os(watchOS)
        private var _progress: Progress
        @available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
        public override var progress: Progress { return self._progress }
        #endif
        
        /// An array returning the errors of the child requests
        public var errors: [Swift.Error?] {
            var rtn: [Swift.Error?] = []
            for t in self.requests { rtn.append(t.error) }
            return rtn
        }
        
        /// An array error of any errors from the child requsts
        public override var error: Swift.Error? {
            let errs = self.errors.compactMap({ return $0 })
            guard errs.count > 0 else { return nil }
            
            return Error.errors(errs)
        }
        
        
        /// The overall state of the child requests
        public override var state: WebRequest.State {
            guard !self.hasBeenCancelled else { return WebRequest.State.canceling }
            
            let states: [WebRequest.State] = [.suspended, .running, .canceling, .completed]
            for s in states {
                //If all states are the same, return that state value
                if self.requests.filter({ $0.state == s }).count == self.requests.count { return s }
            }
            
            // If we have any running or suspended requests, we return running state
            if self.requests.first(where: { $0.state == .running || $0.state == .suspended }) != nil { return WebRequest.State.running }
            // If all states are completed or canceling then we return completed
            if self.requests.filter({ $0.state == .completed || $0.state == .canceling }).count == self.requests.count { return WebRequest.State.completed }
            
            //Return default state
            return WebRequest.State.running
            
        }
        
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        public init(_ requests: @autoclosure ()->[WebRequest],
                    maxConcurrentRequests: Int? = nil,
                    queueName: String? = nil) {
            let reqs = requests()
            precondition(reqs.count > 0, "Must have atleast one request in array")
            
            if let mx = maxConcurrentRequests { self.operationQueue.maxConcurrentOperationCount = mx }
            if let name = queueName { self.operationQueue.name = name }
            self.operationQueue.isSuspended = true
            self.requests = reqs
            self.requestsFinished = [Bool](repeating: false, count: reqs.count)
            #if os(macOS) && os(iOS) && os(tvOS) && os(watchOS)
            var totalUnitsCount: Int64 = 0
            if #available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *) {
                totalUnitsCount = requests.reduce(0, {$0 + $1.progress.totalUnitCount })
            }
            self._progress = Progress(totalUnitCount: totalUnitsCount)
            #endif
            super.init()
            
            
            for t in reqs {
                //Propagate user info to child request
                for (k,v) in self.userInfo { t.userInfo[k] = v }
                // Links child to parent.
                t.userInfo[WebRequest.UserInfoKeys.parent] = self
                
                //Setup notification monitoring
                _ = NotificationCenter.default.addObserver(forName: nil,
                                                           object: t,
                                                           queue: nil,
                                                           using: self.webRequestEventMonitor)
                
                #if os(macOS) && os(iOS) && os(tvOS) && os(watchOS)
                if #available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *) {
                    self._progress.addChild(t.progress, withPendingUnitCount: t.progress.totalUnitCount)
                }
                #endif
                self.operationQueue.addOperation {
                    t.resume()
                    // We are waiting for task to finish
                    t.waitUntilComplete()
                }
            }
            
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ requests: @autoclosure ()->[WebRequest],
                                     maxConcurrentRequests: Int? = nil,
                                     queueName: String? = nil,
                                     completionHandler: @escaping ([WebRequest]) -> Void) {
            self.init(requests, maxConcurrentRequests: maxConcurrentRequests, queueName: queueName)
            self.completionHandler = completionHandler
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ requests: WebRequest...,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: @escaping ([WebRequest]) -> Void) {
            self.init(requests,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        public convenience init(_ requests: @autoclosure ()->[URLRequest],
                                usingSession session: @autoclosure ()->URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil) {
            let webRequests = requests().map( { SingleRequest($0, usingSession: session) })
            self.init(webRequests,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName)
            
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        public convenience init(_ requests: URLRequest...,
                                usingSession session: @autoclosure ()->URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil) {
            self.init(requests,
                      usingSession: session,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName)
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ requests: @autoclosure ()->[URLRequest],
                                usingSession session: @autoclosure ()->URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: @escaping ([WebRequest]) -> Void) {
            
            let webRequests = requests().map( { SingleRequest($0, usingSession: session) })
            self.init(webRequests,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
            
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ requests: URLRequest...,
                                usingSession session: @autoclosure ()->URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: @escaping ([WebRequest]) -> Void) {
            self.init(requests,
                      usingSession: session,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - urls: The individual urls to execute
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        public convenience init(_ urls: @autoclosure ()->[URL],
                                usingSession session: @autoclosure ()->URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil) {
            
            let webRequests = urls().map( { SingleRequest(URLRequest(url: $0), usingSession: session) })
            self.init(webRequests,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName)
            
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - urls: The individual urls to execute
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        public convenience init(_ urls: URL...,
                                usingSession session: @autoclosure ()->URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil) {
            self.init(urls,
                      usingSession: session,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName)
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - urls: The individual urls to execute
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ urls: @autoclosure ()->[URL],
                                usingSession session: @autoclosure ()->URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: @escaping ([WebRequest]) -> Void) {
            
            let webRequests = urls().map( { SingleRequest(URLRequest(url: $0), usingSession: session) })
            self.init(webRequests,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
            
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - urls: The individual urls to execute
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ urls: URL...,
                                usingSession session: @autoclosure ()->URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: @escaping ([WebRequest]) -> Void) {
            self.init(urls,
                      usingSession: session,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        private func webRequestEventMonitor(notification: Notification) -> Void {
            if self.completionHandlerLockingQueue.sync(execute: { return self.hasCalledCompletionHandler }) { return }
            func doCompleteCheck() {
                self.completionHandlerLockingQueue.sync {
                    
                    //print("[\(Thread.current)] - \(self).hasCompletedRequests: \(self.hasCompletedRequests)")
                    if !self.hasCalledCompletionHandler &&
                        self.requestsFinished.filter({$0}).count == self.requests.count {
                        //Stop monitoring for child request events
                        //for r in self.requests { NotificationCenter.default.removeObserver(self, name: nil, object: r) }
                        //NotificationCenter.default.removeObserver(self)
                        self.hasCalledCompletionHandler = true
                        self.triggerStateChange(.completed)
                        
                        if let handler = self.completionHandler {
                            self.callAsyncEventHandler { handler(self.requests) }
                        }
                    }
                }
            }
           
            guard let request = notification.object as? WebRequest else { return }
            guard let idx = self.requests.index(of: request) else { return }
            
            let name = notification.name.rawValue + "Child"
            let newNot = Notification.Name(rawValue: name)
            
            
            var info = notification.userInfo ?? [:]
            info[Notification.Name.WebRequest.Keys.ChildRequest] = request
            info[Notification.Name.WebRequest.Keys.ChildIndex] = idx
            
            
            //Propogate child event to group event
            NotificationCenter.default.post(name: newNot, object: self, userInfo: info)
            
            if notification.name == Notification.Name.WebRequest.DidCancel {
                if let handler = self.singleRequestCancelled { self.callAsyncEventHandler { handler(self, idx, request) } }
                self.requestsFinished[idx] = true
                doCompleteCheck()
            } else if notification.name == Notification.Name.WebRequest.DidComplete {
                if let handler = self.singleRequestCompleted { self.callAsyncEventHandler { handler(self, idx, request) } }
                self.requestsFinished[idx] = true
                doCompleteCheck()
            } else if notification.name == Notification.Name.WebRequest.DidResume {
                if let handler = self.singleRequestResumed { self.callAsyncEventHandler { handler(self, idx, request) } }
            } else if notification.name == Notification.Name.WebRequest.DidStart {
                if let handler = self.singleRequestStarted { self.callAsyncEventHandler { handler(self, idx, request) } }
            } else if notification.name == Notification.Name.WebRequest.DidSuspend {
                if let handler = self.singleRequestSuspended { self.callAsyncEventHandler { handler(self, idx, request) } }
            } else if notification.name == Notification.Name.WebRequest.StateChanged {
                if let state = info[Notification.Name.WebRequest.Keys.State] as? WebRequest.State {
                    if let handler = self.singleRequestStateChanged { self.callAsyncEventHandler { handler(self, idx, request, state) } }
                }
            }

        }
        
        
        /// Resumes the task, if it is suspended.
        public override func resume() {
            
            if self.suspendedRequests.count == 0 { self.operationQueue.isSuspended = false }
            else {
                for i in self.suspendedRequests { self.requests[i].resume() }
                self.suspendedRequests.removeAll()
            }
            
            //Ensures we call the super so proper events get signaled
            super.resume()
        }
        
        
        /// Temporarily suspends a task.
        public override func suspend() {
            guard self.suspendedRequests.count == 0 else { return }
            
            for (i, r) in self.requests.enumerated() {
                if r.state == .running { self.suspendedRequests.append(i)  }
            }
            if self.suspendedRequests.count == 0 { self.operationQueue.isSuspended = true }
            else {
                for i in self.suspendedRequests { self.requests[i].suspend() }
            }
            
            //Ensures we call the super so proper events get signaled
            super.suspend()
        }
        
        /// Cancels the task
        public override func cancel() {
            
            //Cancel all outstanding requests
            for r in self.requests {
                //if r.state == .running || r.state == .suspended { r.cancel()  }
                r.cancel()
            }
            
            self.hasBeenCancelled = true
            self.operationQueue.cancelAllOperations()
            
            //Ensures we call the super so proper events get signaled
            super.cancel()
        }
    }
}

