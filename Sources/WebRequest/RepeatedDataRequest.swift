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
    
    struct RepeatedDataRequestConstants {
        /// Default interval between repeated requests
        public static let DEFAULT_REPEAT_INTERVAL: TimeInterval = 5
    }
    
    @available(*, deprecated, renamed: "RepeatedDataRequestConstants")
    typealias RepeatedRequestConstants = RepeatedDataRequestConstants
    
    struct RequestGenerator {
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
        
        
        /// Create new generator using the given URLRequest
        /// - parameters:
        ///   - generator: The method used to retrieve the URLRequest
        ///   - update: The method used to update the requets parameters and headers
        public static func request(_ generate: @escaping (URLRequest?, Int) -> URLRequest,
                               update: ((_ parameters: inout [URLQueryItem]?,
                                          _ headers: inout [String: String]?,
                                          _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
            return .init(.request(generate, update))
        }
        /// Create new generator using the given URLRequest
        /// - parameters:
        ///   - generator: The method used to retrieve the URLRequest
        ///   - update: The method used to update the requets parameters and headers
        public static func request(_ generate: @escaping @autoclosure() -> URLRequest,
                               update: ((_ parameters: inout [URLQueryItem]?,
                                          _ headers: inout [String: String]?,
                                          _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
            return .init(.request({ _,_ in return generate() }, update))
        }
        /// Create new generator using the given URLRequest
        /// - parameters:
        ///   - value: The URLRequest to use
        ///   - update: The method used to update the requets parameters and headers
        public static func request(value: URLRequest,
                               update: ((_ parameters: inout [URLQueryItem]?,
                                          _ headers: inout [String: String]?,
                                          _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
            return .init(.request({ _,_ in return value }, update))
        }
        
        /// Create new generator using the given URL
        /// - parameters:
        ///   - generator: The method used to retrieve the URL
        ///   - update: The method used to update the requets parameters and headers
        public static func url(_ generate: @escaping (URL?, Int) -> URL,
                               update: ((_ parameters: inout [URLQueryItem]?,
                                          _ headers: inout [String: String]?,
                                          _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
            return .init(.url(generate, update))
        }
        /// Create new generator using the given URL
        /// - parameters:
        ///   - generator: The method used to retrieve the URL
        ///   - update: The method used to update the requets parameters and headers
        public static func url(_ generate: @escaping @autoclosure() -> URL,
                               update: ((_ parameters: inout [URLQueryItem]?,
                                          _ headers: inout [String: String]?,
                                          _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
            return .init(.url({ _,_ in return generate() }, update))
        }
        /// Create new generator using the given URL
        /// - parameters:
        ///   - value: The URL to use
        ///   - update: The method used to update the requets parameters and headers
        public static func url(value: URL,
                               update: ((_ parameters: inout [URLQueryItem]?,
                                          _ headers: inout [String: String]?,
                                          _ repeatCount: Int) -> Void)? = nil) -> RequestGenerator {
            return .init(.url({ _,_ in return value }, update))
        }
        
        /// Generate a URLRequest
        ///
        /// - parameters:
        ///   - previousRequest: The repvious request.  Used to copy additional request details
        ///   - repeatCount: The repeat execution count.  Starting number is 0
        /// - returns: Returns the newly created URLRequest based on provided details
        public func generate(previousRequest: URLRequest? = nil, repeatCount: Int = 0) -> URLRequest {
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
                                               resolvingAgainstBaseURL: true)!
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
    
    @available(*, deprecated, renamed: "RepeatedDataRequest")
    typealias RepeatedRequest<T> = RepeatedDataRequest<T>
    /// RepeatedRequest allows for excuting the same request repeatidly until a certain condition.
    /// Its good for when polling a server for some sort of state change like running a task and waiting for it to complete
    class RepeatedDataRequest<T>: WebRequest {
        
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
        
        private var _state: State = .suspended
        public override var state: State { return self._state }
        
        private let repeatInterval: TimeInterval
        private var repeatCount: Int = 0
        
        private var webRequest: DataRequest? = nil
        private var notificationCenterObserver: NSObjectProtocol? = nil
        private let notificationCenterEventQueue: OperationQueue = OperationQueue()
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
        private let session: URLSession
        private let delegate: DataBaseRequest.URLSessionDataTaskEventHandler
        
        private var completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil
        private let completionHandlerLockingQueue: DispatchQueue = DispatchQueue(label: "org.webrequest.WebRequest.CompletionHandler.Locking")
        private var hasCalledCompletionHandler: Bool = false
        
        /// Repeat handler is the event handler that gets called to indicate if the class should repeat or not.
        /// It allwos for results to be passed from here to the completion handler so they do not need to be parsed twice.
        private var repeatHandler: ((RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults)? = nil
        
        
        /// The URL request object currently being handled by the request.
        public private(set) var currentRequest: URLRequest
        /// The original request object passed when the request was created.
        public let originalRequest: URLRequest
     
        /// Create a new WebRequest using the provided request generator and session.
        public init(requestGenerator: RequestGenerator,
                    usingSession session: @escaping @autoclosure () -> URLSession,
                    repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                    repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                    completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            self.repeatInterval = repeatInterval
            self.requestGenerator = requestGenerator
            let delegate = DataBaseRequest.URLSessionDataTaskEventHandler()
            self.delegate = delegate
            self.session = URLSession(copy: session(), delegate: delegate)
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
                                repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            
            self.init(requestGenerator: .request({ _, _ in return request() }, update: updateRequestDetails),
                      usingSession: session(),
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
                                repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            
            self.init(requestGenerator: .request(request, update: updateRequestDetails),
                      usingSession: session(),
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
                                repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            self.init(requestGenerator: .url({ _, _ in return url() }, update: updateRequestDetails),
                      usingSession: session(),
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
                                repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            self.init(requestGenerator: .url(url, update: updateRequestDetails),
                      usingSession: session(),
                      repeatInterval: repeatInterval,
                      repeatHandler: repeatHandler,
                      completionHandler: completionHandler)
        }
        
        
        deinit {
           self.cancelRequest()
            if let observer = self.notificationCenterObserver {
                NotificationCenter.default.removeObserver(observer)
                self.notificationCenterObserver = nil
            }
            self.webRequest?.emptyResultsData()
            self.webRequest = nil
        }
        
        private func createRequest(repeatCount: Int) {
            
            self.currentRequest =  {
                guard repeatCount > 0 else { return self.originalRequest }
                return self.requestGenerator.generate(previousRequest: self.currentRequest,
                                                      repeatCount: self.repeatCount)
            }()
            
            // Empty out links/data for current data request
            if let observer = self.notificationCenterObserver {
                // Stop observing old request
                NotificationCenter.default.removeObserver(observer)
                self.notificationCenterObserver = nil
            }
            // Empty old request data
            self.webRequest?.emptyResultsData()
            self.webRequest = nil
            
            self.webRequest = DataRequest(self.currentRequest,
                                          usingSession: self.session,
                                          eventDelegate: self.delegate) {  [weak self] requestResults in
                
                guard self != nil else { return }
                
                // Empty out links/data for current data request
                if let observer = self?.notificationCenterObserver {
                    // Stop observing old request
                    NotificationCenter.default.removeObserver(observer)
                    self?.notificationCenterObserver = nil
                }
                // Empty old request data
                self?.webRequest?.emptyResultsData()
                self?.webRequest = nil
                
                
                // Get response error if any
                var err: Swift.Error? = requestResults.error
                var shouldContinue: Bool = true
                var results: T? = nil
                if shouldContinue { //If we are ok to continue so far we should call repeatHandler
                    do {
                        if let f = self?.repeatHandler {
                            //Call repeat handler
                            let r = try f(self!, requestResults, self!.repeatCount)
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
                    if let s = self {
                        let t = DispatchTime.now() + s.repeatInterval
                        DispatchQueue.global().asyncAfter(deadline: t) { [weak self] in
                            guard let s = self else { return }
                            guard s.state == .running else { return }
                            
                            s.repeatCount += 1
                            s.createRequest(repeatCount: s.repeatCount)
                        }
                    }
                } else {
                    
                    let finishState = (self?.webRequest?.state ?? .completed)
                    self?._state = finishState
                    self?._error = err
                    // We are no longer repeating.  Lets trigger the proper event handlers.
                    self?.triggerStateChange(finishState)
                    self?.completionHandlerLockingQueue.sync {
                        self?.hasCalledCompletionHandler = true
                    }
                    if let handler = self?.completionHandler {
                        /// was async
                        self?.callSyncEventHandler {
                            handler(requestResults, results, err)
                        }
                    }
                    
                }
                
                
            }
            
            //Propagate user info to repeated request
            for (k,v) in self.userInfo { self.webRequest!.userInfo[k] = v }
            
            
            //Setup notification monitoring
            self.notificationCenterObserver = NotificationCenter.default.addObserver(forName: nil,
                                                                                     object: self.webRequest!,
                                                                                     queue: self.notificationCenterEventQueue,
                                                                                     using: self.webRequestEventMonitor)
            
            
            self.webRequest?.resume()
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
            
            // If we cancel with no child request
            if self.webRequest == nil ||
                // Or has a child request without a resposne
               !(self.webRequest?.results.hasResponse ?? false) ||
                // Or a child request with a canceling resposne
               (self.webRequest?.state == .canceling) {
                
                let results = DataRequest.Results(request: self.currentRequest,
                                                  response: nil,
                                                  error: DataRequest.createCancelationError(forURL: self.currentRequest.url!),
                                                  data: self.webRequest?.results.data)
                
                if let f = self.completionHandler {
                    /// was async
                    self.callSyncEventHandler { f(results, nil, results.error) }
                }
                
            }
            
            //Cancel all outstanding requests
            self.cancelRequest()
            //Ensures we call the super so proper events get signaled
            super.cancel()
            self._state = .canceling
            
        }
        
        private func cancelRequest() {
            self.webRequest?.cancel()
            self.webRequest = nil
            if let observer = self.notificationCenterObserver {
                NotificationCenter.default.removeObserver(observer)
                self.notificationCenterObserver = nil
            }
            
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
