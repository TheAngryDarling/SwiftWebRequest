//
//  RepeatedRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2018-07-11.
//

import Foundation

public extension WebRequest {
    
    public struct RepeatedRequestConstants {
        public static let DEFAULT_REPEAT_INTERVAL: TimeInterval = 5 //60
    }
    
    /*
     RepeatedRequest allows for excuting the same request repeatidly until a certain condition.
     Its good for when polling a server for some sort of state change like running a task and waiting for it to complete
     */
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public class RepeatedRequest<T>: WebRequest {
        
        //public static let DEFAULT_REPEAT_INTERVAL: TimeInterval = 60
        
        public enum RepeatResults {
            case `repeat`
            case results(T?)
            
            fileprivate var shouldRepeat: Bool {
                guard case RepeatResults.repeat = self else { return false }
                return true
            }
            
            fileprivate var finishedResults: T? {
                guard case let RepeatResults.results(r) = self else { return nil }
                return r
            }
        }
        
        private var _state: State = .suspended
        public override var state: State { return self._state }
        
        private let repeatInterval: TimeInterval
        private var repeatCount: Int = 0
        
        private var webRequest: SingleRequest? = nil
        //private let request: URLRequest
        //private let session: URLSession
        
        
        
        private let request: () -> URLRequest
        private let session: () -> URLSession
        
        private var completionHandler: ((SingleRequest.Results, T?, Swift.Error?) -> Void)? = nil
        private let completionHandlerLockingQueue: DispatchQueue = DispatchQueue(label: "org.webrequest.WebRequest.CompletionHandler.Locking")
        private var hasCalledCompletionHandler: Bool = false
        
        //Repeat handler is the event handler that gets called to indicate if the class should repeat or not.  It allwos for results to be passed from here to the completion handler so they do not need to be parsed twice.
        private var repeatHandler: ((SingleRequest.Results, Int) throws -> RepeatResults)? = nil
        
        
        // The URL request object currently being handled by the request.
        public private(set) var currentRequest: URLRequest
        // The original request object passed when the request was created.
        public let originalRequest: URLRequest
     
        // Create a new WebRequest using the provided request and session.
        public init(_ request: @escaping @autoclosure () -> URLRequest,
                    usingSession session: @escaping @autoclosure () -> URLSession,
                    repeatInterval: TimeInterval = { return RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL }(),
                    repeatHandler: @escaping (SingleRequest.Results, Int) throws -> RepeatResults) {
            self.repeatInterval = repeatInterval
            //var workingRequest = request
            // Ensures that we get a real data instaed of cached data
            //workingRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            self.request = request
            self.session = session
            self.repeatHandler = repeatHandler
            
            self.originalRequest = request()
            self.currentRequest = originalRequest
            
            super.init()
            
            
        }
        
        // Create a new WebRequest using the provided url and session
        public convenience init(_ url: @escaping @autoclosure () -> URL,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = { return RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL }(),
                                repeatHandler: @escaping (SingleRequest.Results, Int) throws -> RepeatResults ) {
            self.init(URLRequest(url: url()), usingSession: session, repeatInterval: repeatInterval, repeatHandler: repeatHandler)
        }
        
        // Create a new WebRequest using the provided requset and session. and call the completionHandler when finished
        public convenience init(_ request: @escaping @autoclosure () -> URLRequest,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = { return RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL }(),
                                repeatHandler: @escaping (SingleRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: @escaping (SingleRequest.Results, T?, Swift.Error?) -> Void) {
            self.init(request, usingSession: session, repeatInterval: repeatInterval, repeatHandler: repeatHandler)
            self.completionHandler = completionHandler
        }
        
        // Create a new WebRequest using the provided url and session. and call the completionHandler when finished
        public convenience init(_ url: @escaping @autoclosure () -> URL,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = { return RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL }(),
                                repeatHandler: @escaping (SingleRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: @escaping (SingleRequest.Results, T?, Swift.Error?) -> Void) {
            self.init(URLRequest(url: url()), usingSession: session, repeatInterval: repeatInterval, repeatHandler: repeatHandler, completionHandler: completionHandler)
        }
        
        
        deinit {
           self.cancelRequest()
        }
        
        private func createRequest(isFirstRequest: Bool = false) {
            let req: URLRequest = isFirstRequest ? self.originalRequest : self.request()
            self.currentRequest = req
            let wR = SingleRequest(req, usingSession: self.session()) { requestResults in
                self.webRequest = nil
                
                
                // Get response error if any
                var err: Swift.Error? = requestResults.error
                var shouldContinue: Bool = true
                var results: T? = nil
                if shouldContinue { //If we are ok to continue so far we should call repeatHandler
                    do {
                        if let f = self.repeatHandler {
                            //Call repeat handler
                            let r = try f(requestResults, self.repeatCount)
                            shouldContinue = r.shouldRepeat
                            if !shouldContinue { results = r.finishedResults }
                            //results = r.results
                            //shouldContinue = r.repeat
                        } else {
                            // No repeat handler set.  so we stop repeating
                            shouldContinue = false
                        }
                    } catch {
                        err = error
                    }
                }
                
                if shouldContinue {
                    // If we should repeat, then setup new block for execution in repeat interval.
                    // Tried using a Timer but it wouldn't execute so changed to DispatchQueue
                    let t = DispatchTime.now() + self.repeatInterval
                    DispatchQueue.global().asyncAfter(deadline: t) { [weak self] in
                        guard let s = self else { return }
                        guard s.state == .running else { return }
                        
                        s.repeatCount += 1
                        s.createRequest()
                    }
                } else {
                    self._state = .completed
                    // We are no longer repeating.  Lets trigger the proper event handlers.
                    self.triggerStateChange(.completed)
                    self.completionHandlerLockingQueue.sync { self.hasCalledCompletionHandler = true }
                    if let handler = self.completionHandler {
                        self.callAsyncEventHandler { handler(requestResults, results, err) }
                    }
                    
                }
                
                
            }
            //Setup notification monitoring
            _ = NotificationCenter.default.addObserver(forName: nil,
                                                       object: wR,
                                                       queue: nil,
                                                       using: self.webRequestEventMonitor)
            self.webRequest = wR
            
            
            wR.resume()
        }
        
        // Resumes the task, if it is suspended.
        public override func resume() {
            guard self._state == .suspended else { return }
            
            if let r = self.webRequest { r.resume() }
            else {
                // Must create sub request
                self.createRequest(isFirstRequest: true)
            }
            
            //Ensures we call the super so proper events get signaled
            super.resume()
            self._state = .running
        }
        
        
        // Temporarily suspends a task.
        public override func suspend() {
            guard self._state == .running else { return }
            if let r = self.webRequest { r.suspend() }
            //Ensures we call the super so proper events get signaled
            super.suspend()
            self._state = .suspended
        }
        
        // Cancels the task
        public override func cancel() {
            guard self._state != .canceling && self._state != .completed else { return }
            
            let hasRequest: Bool = (self.webRequest != nil)
            //Cancel all outstanding requests
            self.cancelRequest()
            //Ensures we call the super so proper events get signaled
            super.cancel()
            self._state = .canceling
            if !hasRequest {
                
                let results = SingleRequest.Results(request: self.currentRequest, response: nil, error: SingleRequest.createCancelationError(forURL: self.currentRequest.url!), data: nil)
                if let f = self.completionHandler {
                    self.callAsyncEventHandler { f(results, nil, results.error) }
                }
                
            }
        }
        
        private func cancelRequest() {
            if let r = self.webRequest { r.cancel() }
            self.webRequest = nil
        }
        
        
        private func webRequestEventMonitor(notification: Notification) -> Void {
            
            if self.completionHandlerLockingQueue.sync(execute: { return self.hasCalledCompletionHandler }) { return }
            
            guard let request = notification.object as? WebRequest else { return }
            
            let name = notification.name.rawValue + "Repeat"
            let newNot = Notification.Name(rawValue: name)
            
            var info = notification.userInfo ?? [:]
            info[Notification.Name.WebRequest.Keys.ChildRequest] = request
            
            //Propogate child event to group event
            NotificationCenter.default.post(name: newNot, object: self, userInfo: info)
        }
        
    }
}
