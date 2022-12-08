//
//  GroupWebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2018-06-06.
//

import Foundation
import Dispatch
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
#endif

fileprivate extension ResourceLock where Resource == [Bool] {
    func allEquals(_ value: Bool) -> Bool {
        return self.withUpdatingLock { ary in
            guard !ary.contains(!value) else { return false }
            return true
        }
    }
    
    var count: Int {
        return self.withUpdatingLock { ary in return ary.count }
    }
    subscript(position: Int) -> Bool {
        get {
            return self.withUpdatingLock { ary in
                return ary[position]
            }
        }
        set {
            self.withUpdatingLock { ary in
                ary[position] = newValue
            }
        }
    }
}
public extension WebRequest {
    /// GroupWebRequest allows for excuting multiple WebRequests at the same time
    class GroupRequest: WebRequest {
        
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
        
        
        private let completionHandler: HandlerResourceLock<([WebRequest]) -> Void>
        
        private var operationQueue: OperationQueue = OperationQueue()
        public var maxConcurrentRequestCount: Int {
            get { return self.operationQueue.maxConcurrentOperationCount }
            set { self.operationQueue.maxConcurrentOperationCount = newValue }
        }
        /// array of child web requsts
        public private(set) var requests: [WebRequest]
        private var requestsFinished: ResourceLock<[Bool]>
        private var suspendedRequests: [Int] = []
        
        private var hasBeenCancelled: Bool = false
        
        
        #if _runtime(_ObjC)
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
        
        
        /// The last state set from the resume/suspend/cancel methods
        private var _previousState: WebRequest.State = .suspended
        
        /// The overall state of the child requests
        public override var state: WebRequest.State {
            guard !self.hasBeenCancelled else { return WebRequest.State.canceling }
            
            let states: [WebRequest.State] = [.suspended, .running, .canceling, .completed]
            for s in states {
                //If all states are the same, return that state value
                if self.requests.allSatisfy({ return $0.state == s }) {
                    return s
                }
            }
            // If any request was canceled then we consider the group canceled
            if self.requests.contains(where: { return $0.state == .canceling }) {
                return .canceling
            }
            
            // If we have any running or suspended requests, we return running state
            if self.requests.contains(where: { $0.state == .running || $0.state == .suspended }) {
                return .running
            }
            
            //Return default state
            return WebRequest.State.running
            
        }
        
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - name: Custom Name identifing this request
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public init(_ requests: @autoclosure () -> [WebRequest],
                    name: String? = nil,
                    maxConcurrentRequests: Int? = nil,
                    queueName: String? = nil,
                    completionHandler: (([WebRequest]) -> Void)? = nil) {
            let reqs = requests()
            precondition(reqs.count > 0, "Must have atleast one request in array")
            
            if let mx = maxConcurrentRequests { self.operationQueue.maxConcurrentOperationCount = mx }
            if let name = queueName { self.operationQueue.name = name }
            self.operationQueue.isSuspended = true
            self.requests = reqs
            self.requestsFinished = .init(resource: [Bool](repeating: false, count: reqs.count))
            #if _runtime(_ObjC)
            var totalUnitsCount: Int64 = 0
            if #available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *) {
                totalUnitsCount = reqs.reduce(0, {$0 + $1.progress.totalUnitCount })
            }
            self._progress = Progress(totalUnitCount: totalUnitsCount)
            #endif
            
            self.completionHandler = .init(completionHandler)
            
            super.init(name: name)
            
            
            for t in reqs {
                //Propagate user info to child request
                for (k,v) in self.userInfo { t.userInfo[k] = v }
                // Links child to parent.
                t.userInfo[WebRequest.UserInfoKeys.parent] = self
                
                t.registerStateChangedHandler(handlerID: "GroupRequest[\(self.uid)]",
                                              handler: childRequestStateChanged)
                
                #if _runtime(_ObjC)
                if #available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *) {
                    self._progress.addChild(t.progress, withPendingUnitCount: t.progress.totalUnitCount)
                }
                #endif
                self.operationQueue.addOperation {
                    t.resume()
                    // We are waiting for task to finish
                    t.waitUntilComplete()
                    // Stop monitoring for events
                    t.unregisterStateChangedHandler(for: "GroupRequest[\(self.uid)]")
                    // remove refeference of self from child request
                    t.userInfo[WebRequest.UserInfoKeys.parent] = nil
                }
            }
            
            
        }
        
        
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - name: Custom Name identifing this request
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ requests: WebRequest...,
                                name: String? = nil,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: (([WebRequest]) -> Void)? = nil) {
            self.init(requests,
                      name: name,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - name: Custom Name identifing this request
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ requests: @autoclosure () -> [URLRequest],
                                name: String? = nil,
                                usingSession session: @autoclosure () -> URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: (([WebRequest]) -> Void)? = nil) {
            let webRequests = requests().map( { DataRequest($0,
                                                            usingSession: session()) })
            self.init(webRequests,
                      name: name,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
            
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - requests: The individual requests to execute
        ///   - name: Custom Name identifing this request
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ requests: URLRequest...,
                                name: String? = nil,
                                usingSession session: @autoclosure () -> URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: (([WebRequest]) -> Void)? = nil) {
            self.init(requests,
                      name: name,
                      usingSession: session(),
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - urls: The individual urls to execute
        ///   - name: Custom Name identifing this request
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ urls: @autoclosure () -> [URL],
                                name: String? = nil,
                                usingSession session: @autoclosure () -> URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: (([WebRequest]) -> Void)? = nil) {
            
            let webRequests = urls().map( { DataRequest(URLRequest(url: $0),
                                                        usingSession: session()) })
            self.init(webRequests,
                      name: name,
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
            
        }
        
        /// Create new instance of a group request
        ///
        /// - Parameters:
        ///   - urls: The individual urls to execute
        ///   - name: Custom Name identifing this request
        ///   - session: The URL Session to use when executing the requests
        ///   - maxConcurrentRequests: The maximun number of requests to execute in parallel
        ///   - queueName: The queue name to use
        ///   - completionHandler: The call back when done executing
        public convenience init(_ urls: URL...,
                                name: String? = nil,
                                usingSession session: @autoclosure () -> URLSession,
                                maxConcurrentRequests: Int? = nil,
                                queueName: String? = nil,
                                completionHandler: (([WebRequest]) -> Void)? = nil) {
            self.init(urls,
                      name: name,
                      usingSession: session(),
                      maxConcurrentRequests: maxConcurrentRequests,
                      queueName: queueName,
                      completionHandler: completionHandler)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            // remove any connection of this group request
            // in any child request
            for request in self.requests {
                // Stop monitoring for events
                request.unregisterStateChangedHandler(for: "GroupRequest[\(self.uid)]")
                // remove refeference of self from child request
                request.userInfo[WebRequest.UserInfoKeys.parent] = nil
            }
            // clear array of requests
            self.requests = []
            // removing any reference to any exture closures
            self.singleRequestStarted = nil
            self.singleRequestResumed = nil
            self.singleRequestSuspended = nil
            self.singleRequestCancelled = nil
            self.singleRequestCompleted = nil
            self.completionHandler.withUpdatingLock { r in
                r.handler = nil
            }
        }
        
        private func checkForCompletion(statusChange: WebRequest.ChangeState) {
            self.completionHandler.withUpdatingLock { r in
                guard !r.hasCalled &&
                      self.requestsFinished.allEquals(true) else {
                    return
                }
                
                r.hasCalled = true
                self.triggerStateChange(from: .running, to: statusChange.state)
                
                if let handler = r.handler {
                    self.callSyncEventHandler { handler(self.requests) }
                }
            }
        }
        
        private func sendChildStateChangeEventNotification(childEventName: Notification.Name,
                                                           childRequest: WebRequest,
                                                           childIndex: Int,
                                                           fromState: WebRequest.State,
                                                           toState: WebRequest.ChangeState) {
            
            var userNotificationInfo: [AnyHashable: Any] = childRequest.generateNotificationUserInfoFor(childEventName, fromState: fromState, toState: toState) ?? [:]
            userNotificationInfo[Notification.Name.WebRequest.Keys.ChildRequest] = childRequest
            userNotificationInfo[Notification.Name.WebRequest.Keys.ChildIndex] = childIndex
            
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: childEventName.rawValue + "Child"),
                                            object: self,
                                            userInfo: userNotificationInfo)
            
        }
        
        private func childRequestStateChanged(request: WebRequest,
                                              fromState: WebRequest.State,
                                              toState: WebRequest.ChangeState) -> Void {
            guard !self.completionHandler.hasCalled else { return }
            
            
            guard let idx = self.requests.firstIndex(of: request) else { return }
            
            let (childNotification, doCompleteCheck, event) = {
                    () -> (Notification.Name, Bool, ((GroupRequest, Int, WebRequest) -> Void)?) in
                switch toState {
                    case .canceling:
                        self.requestsFinished[idx] = true
                        return (Notification.Name.WebRequest.DidCancel,
                                true,
                                self.singleRequestCancelled)
                    case .completed:
                        self.requestsFinished[idx] = true
                        return (Notification.Name.WebRequest.DidComplete,
                                true,
                                self.singleRequestCompleted)
                    case .starting:
                        return (Notification.Name.WebRequest.DidStart,
                                false,
                                self.singleRequestStarted)
                    case .running:
                        return (Notification.Name.WebRequest.DidResume,
                                false,
                                self.singleRequestResumed)
                    case .suspended:
                        return (Notification.Name.WebRequest.DidSuspend,
                                false,
                                self.singleRequestSuspended)
                }
            }()
            
            if let handler = self.singleRequestStateChanged {
                self.callAsyncEventHandler {
                    handler(self, idx, request, toState.state)
                }
            }
            /*
            if let handler = self.singleRequestStateChangedFull {
                self.callAsyncEventHandler {
                    handler(self, idx, request, fromState, toState)
                }
            }
            */
            self.sendChildStateChangeEventNotification(childEventName: Notification.Name.WebRequest.StateChanged,
                                                       childRequest: request,
                                                       childIndex: idx,
                                                       fromState: fromState,
                                                       toState: toState)
            
            if let handler = event {
                self.callAsyncEventHandler {
                    handler(self, idx, request)
                }
            }
            
            self.sendChildStateChangeEventNotification(childEventName: childNotification,
                                                       childRequest: request,
                                                       childIndex: idx,
                                                       fromState: fromState,
                                                       toState: toState)
            
            
            if doCompleteCheck {
                checkForCompletion(statusChange: toState)
            }
            
        }
        
        public override func resume() {
            guard self.state == .suspended else { return }
            self._previousState = .running
            
            if self.suspendedRequests.count == 0 { self.operationQueue.isSuspended = false }
            else {
                for i in self.suspendedRequests { self.requests[i].resume() }
                self.suspendedRequests.removeAll()
            }
            
            self.triggerStateChange(from: .suspended, to: .running)
        }
        
        
        public override func suspend() {
            guard self.state == .running else { return }
            self._previousState = .suspended
            self.triggerStateChange(from: .running, to: .suspended)
            
            guard self.suspendedRequests.count == 0 else { return }
            
            for (i, r) in self.requests.enumerated() {
                if r.state == .running { self.suspendedRequests.append(i)  }
            }
            if self.suspendedRequests.count == 0 { self.operationQueue.isSuspended = true }
            else {
                for i in self.suspendedRequests { self.requests[i].suspend() }
            }
            
            
        }
        
        public override func cancel() {
            let currentState = self.state
            guard currentState == .running || currentState == .suspended else { return }
            
            self.hasBeenCancelled = true
            self.triggerStateChange(from: currentState, to: .canceling)
            
            // we don't set canceling because if we d
            // and the completion handler is called it will see
            // previous state and current state as the same
            //self._previousState = .canceling
            
            self.completionHandler.withUpdatingLock { r in
                guard !r.hasCalled else { return }
                r.hasCalled = true
                if let handler = r.handler {
                    /// was async
                    self.callSyncEventHandler { handler(self.requests) }
                }
            }
            
            
            //Cancel all outstanding requests
            for r in self.requests {
                //if r.state == .running || r.state == .suspended { r.cancel()  }
                r.cancel()
            }
            
            
            self.operationQueue.cancelAllOperations()
            
            
        }
    }
}

