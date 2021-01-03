//
//  RepeatedRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2018-07-11.
//

import Foundation
import Dispatch
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif

public extension WebRequest {
    
    struct RepeatedRequestConstants {
        /// Default interval between repeated requests
        public static let DEFAULT_REPEAT_INTERVAL: TimeInterval = 5
    }
    
    /// RepeatedRequest allows for excuting the same request repeatidly until a certain condition.
    /// Its good for when polling a server for some sort of state change like running a task and waiting for it to complete
    class RepeatedRequest<T>: WebRequest {
        
        public enum RepeatResults {
            /// Indicator that the RepeatedRequest should continue
            case `repeat`
            /// Indicator that the RepeatedRequest should stop
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
        
        public struct RequestGenerator {
            private enum Choice {
                case request((URLRequest?, Int) -> URLRequest,
                              ((inout [URLQueryItem]?,
                                inout [String: String]?,
                                Int) -> Void)?)
                case url((URL?, Int) -> URL,
                          ((inout [URLQueryItem]?,
                           inout [String: String]?,
                           Int) -> Void)?)
                
                fileprivate var updateFields: ((inout [URLQueryItem]?,
                                                inout [String: String]?,
                                                Int) -> Void)? {
                    switch self {
                        case .request(_, let f), .url(_, let f): return f
                    }
                }
            }
            
            private let choice: Choice
            private init(_ choice: Choice) { self.choice = choice }
            
            
            public static func request(_ generate: @escaping (URLRequest?, Int) -> URLRequest,
                                   update: ((_ parameters: inout [URLQueryItem]?,
                                              _ headers: inout [String: String]?,
                                              _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
                return .init(.request(generate, update))
            }
            public static func request(_ generate: @escaping @autoclosure() -> URLRequest,
                                   update: ((_ parameters: inout [URLQueryItem]?,
                                              _ headers: inout [String: String]?,
                                              _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
                return .init(.request({ _,_ in return generate() }, update))
            }
            
            public static func url(_ generate: @escaping (URL?, Int) -> URL,
                                   update: ((_ parameters: inout [URLQueryItem]?,
                                              _ headers: inout [String: String]?,
                                              _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
                return .init(.url(generate, update))
            }
            public static func url(_ generate: @escaping @autoclosure() -> URL,
                                   update: ((_ parameters: inout [URLQueryItem]?,
                                              _ headers: inout [String: String]?,
                                              _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
                return .init(.url({ _,_ in return generate() }, update))
            }
            
            func generate(previousRequest: URLRequest?, repeatCount: Int) -> URLRequest {
                var rtnRequest: URLRequest? = nil
                switch self.choice {
                    case .request(let f, _): rtnRequest = f(previousRequest, repeatCount)
                    case .url(let f, _):
                        let url = f(previousRequest?.url, repeatCount)
                        if let pr = previousRequest {
                            rtnRequest = URLRequest(url: url, pr)
                        } else {
                            rtnRequest = URLRequest(url: url)
                        }
                }
                
                precondition(rtnRequest != nil, "Failed to generate new URLRequest")
                precondition(rtnRequest!.url != nil, "URLRequest missing URL")
                
                if let f = self.choice.updateFields {
                    var components = URLComponents(url: rtnRequest!.url!,
                                                   resolvingAgainstBaseURL: false)!
                    var params = components.queryItems
                    var headers = rtnRequest?.allHTTPHeaderFields
                    
                    f(&params, &headers, repeatCount)
                    
                    components.queryItems = params
                    rtnRequest!.url = components.url!
                    rtnRequest!.allHTTPHeaderFields = headers
                }
                
                
                return rtnRequest!
            }
        }
        
        private var _state: State = .suspended
        public override var state: State { return self._state }
        
        private let repeatInterval: TimeInterval
        private var repeatCount: Int = 0
        
        private var webRequest: SingleRequest? = nil
        //private let request: URLRequest
        //private let session: URLSession
        
        private var _error: Error? = nil
        public override var error: Error? { return _error }
        
        #if _runtime(_ObjC)
        private var _progress: Progress
        @available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
        public override var progress: Progress { return self._progress }
        #endif
        
        private let requestGenerator: RequestGenerator
        private let session: () -> URLSession
        
        private var completionHandler: ((SingleRequest.Results, T?, Swift.Error?) -> Void)? = nil
        private let completionHandlerLockingQueue: DispatchQueue = DispatchQueue(label: "org.webrequest.WebRequest.CompletionHandler.Locking")
        private var hasCalledCompletionHandler: Bool = false
        
        /// Repeat handler is the event handler that gets called to indicate if the class should repeat or not.
        /// It allwos for results to be passed from here to the completion handler so they do not need to be parsed twice.
        private var repeatHandler: ((RepeatedRequest<T>, SingleRequest.Results, Int) throws -> RepeatResults)? = nil
        
        
        /// The URL request object currently being handled by the request.
        public private(set) var currentRequest: URLRequest
        /// The original request object passed when the request was created.
        public let originalRequest: URLRequest
     
        /// Create a new WebRequest using the provided request generator and session.
        public init(requestGenerator: RequestGenerator,
                    usingSession session: @escaping @autoclosure () -> URLSession,
                    repeatInterval: TimeInterval = RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL,
                    repeatHandler: @escaping (RepeatedRequest<T>, SingleRequest.Results, Int) throws -> RepeatResults,
                    completionHandler: ((SingleRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            self.repeatInterval = repeatInterval
            self.requestGenerator = requestGenerator
            self.session = session
            self.repeatHandler = repeatHandler
            self.completionHandler = completionHandler
            
            self.originalRequest = requestGenerator.generate(previousRequest: nil, repeatCount: 0)
            self.currentRequest = self.originalRequest
            
            #if _runtime(_ObjC)
            self._progress = Progress(totalUnitCount: 0)
            #endif
            
            super.init()
        }
        
        /// Create a new WebRequest using the provided request and session.
        public convenience init(_ request: @escaping @autoclosure () -> URLRequest,
                                updateRequestDetails: ((_ parameters: inout [URLQueryItem]?,
                                                        _ headers: inout [String: String]?,
                                                        _ repeatCount: Int) -> Void)? = nil,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedRequest<T>, SingleRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((SingleRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            
            self.init(requestGenerator: .request(request, update: updateRequestDetails),
                      usingSession: session,
                      repeatInterval: repeatInterval,
                      repeatHandler: repeatHandler,
                      completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided request and session.
        public convenience init(_ request: @escaping (_ previousRequest: URLRequest?,
                                                      _ repeatCount: Int) -> URLRequest,
                                updateRequestDetails: ((_ parameters: inout [URLQueryItem]?,
                                                        _ headers: inout [String: String]?,
                                                        _ repeatCount: Int) -> Void)? = nil,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedRequest<T>, SingleRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((SingleRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            
            self.init(requestGenerator: .request(request, update: updateRequestDetails),
                      usingSession: session,
                      repeatInterval: repeatInterval,
                      repeatHandler: repeatHandler,
                      completionHandler: completionHandler)
        }
        
        // Create a new WebRequest using the provided url and session
        public convenience init(_ url: @escaping @autoclosure () -> URL,
                                updateRequestDetails: ((_ parameters: inout [URLQueryItem]?,
                                                        _ headers: inout [String: String]?,
                                                        _ repeatCount: Int) -> Void)? = nil,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedRequest<T>, SingleRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((SingleRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            self.init(requestGenerator: .url(url, update: updateRequestDetails),
                      usingSession: session,
                      repeatInterval: repeatInterval,
                      repeatHandler: repeatHandler,
                      completionHandler: completionHandler)
        }
        
        // Create a new WebRequest using the provided url and session
        public convenience init(_ url: @escaping (_ previousURL: URL?,
                                                  _ repeatCount: Int) -> URL,
                                updateRequestDetails: ((_ parameters: inout [URLQueryItem]?,
                                                        _ headers: inout [String: String]?,
                                                        _ repeatCount: Int) -> Void)? = nil,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = RepeatedRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedRequest<T>, SingleRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((SingleRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            self.init(requestGenerator: .url(url, update: updateRequestDetails),
                      usingSession: session,
                      repeatInterval: repeatInterval,
                      repeatHandler: repeatHandler,
                      completionHandler: completionHandler)
        }
        
        
        deinit {
           self.cancelRequest()
        }
        
        private func createRequest(repeatCount: Int) {
            
            let req: URLRequest =  {
                guard repeatCount > 0 else { return self.originalRequest }
                return self.requestGenerator.generate(previousRequest: self.currentRequest,
                                                      repeatCount: self.repeatCount)
            }()
            
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
                            let r = try f(self, requestResults, self.repeatCount)
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
                        s.createRequest(repeatCount: s.repeatCount)
                    }
                } else {
                    self._state = .completed
                    self._error = err
                    // We are no longer repeating.  Lets trigger the proper event handlers.
                    self.triggerStateChange(.completed)
                    self.completionHandlerLockingQueue.sync { self.hasCalledCompletionHandler = true }
                    if let handler = self.completionHandler {
                        self.callAsyncEventHandler { handler(requestResults, results, err) }
                    }
                    
                }
                
                
            }
            
            //Propagate user info to repeated request
            for (k,v) in self.userInfo { wR.userInfo[k] = v }
            
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
            
            //Ensures we call the super so proper events get signaled
            super.resume()
            self._state = .running
            
            if let r = self.webRequest { r.resume() }
            else {
                // Must create sub request
                self.createRequest(repeatCount: 0)
            }
            
           
        }
        
        
        // Temporarily suspends a task.
        public override func suspend() {
            guard self._state == .running else { return }
            
            //Ensures we call the super so proper events get signaled
            super.suspend()
            self._state = .suspended
            if let r = self.webRequest { r.suspend() }
            
        }
        
        // Cancels the task
        public override func cancel() {
            guard self._state != .canceling && self._state != .completed else { return }
            
            if (self.webRequest == nil) {
                let results = SingleRequest.Results(request: self.currentRequest, response: nil, error: SingleRequest.createCancelationError(forURL: self.currentRequest.url!), data: nil)
                if let f = self.completionHandler {
                    self.callAsyncEventHandler { f(results, nil, results.error) }
                }
                
            }
            
            //Cancel all outstanding requests
            self.cancelRequest()
            //Ensures we call the super so proper events get signaled
            super.cancel()
            self._state = .canceling
            
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
