//
//  RepeatedRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2018-07-11.
//

import Foundation
import Dispatch
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
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
    /// Results of the repeated request
    struct RepeatedDataRequestResults<ResultObject> {
        
        /// Repeat parsed Object
        public let object: ResultObject?
        public let request: URLRequest
        public let response: URLResponse?
        public let error: Error?
        
        
        public init(object: ResultObject? = nil,
                    request: URLRequest,
                    response: URLResponse? = nil,
                    error: Error? = nil) {
            self.object = object
            self.request = request
            self.response = response
            self.error = error
        }
        
        public init(object: ResultObject? = nil,
                    dataResults: DataRequest.Results) {
            self.init(object: object,
                      request: dataResults.request,
                      response: dataResults.response,
                      error: dataResults.error)
        }
    }
    
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
        
        /// Results of the repeated request
        public typealias Results = RepeatedDataRequestResults<T>
        
        private var _state: State = .suspended
        public override var state: State { return self._state }
        
        private let repeatInterval: TimeInterval
        private var repeatCount: Int = 0
        
        private var webRequest: DataRequest? = nil
        private var notificationCenterObserver: NSObjectProtocol? = nil
        private let notificationCenterEventQueue: OperationQueue = OperationQueue()
        //private let request: URLRequest
        //private let session: URLSession
        
        public private(set) var results: Results
        
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
        
        private let completionHandlers: HandlerResourceLock<[String:(_ request: RepeatedDataRequest,
                                                                     _ results: DataRequest.Results,
                                                                     _ object: T?,
                                                                     _ error: Swift.Error?) -> Void]>
        
        /// Repeat handler is the event handler that gets called to indicate if the class should repeat or not.
        /// It allwos for results to be passed from here to the completion handler so they do not need to be parsed twice.
        private var repeatHandler: ((RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults)? = nil
        
        
        /// The URL request object currently being handled by the request.
        public private(set) var currentRequest: URLRequest
        /// The original request object passed when the request was created.
        public let originalRequest: URLRequest
     
        /// Create a new WebRequest using the provided request generator and session.
        public init(requestGenerator: RequestGenerator,
                    name: String? = nil,
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
            self.completionHandlers = .init([:])
            
            
            self.originalRequest = requestGenerator.generate(previousRequest: nil, repeatCount: 0)
            self.currentRequest = self.originalRequest
            
            #if _runtime(_ObjC)
            self._progress = Progress(totalUnitCount: 0)
            #endif
            
            self.results = .init(request: self.originalRequest)
            
            super.init(name: name)
            
            if let ch = completionHandler {
                self.registerCompletionHandler { request, results, object, error in
                    ch(results, object, error)
                }
            }
        }
        
        /// Create a new WebRequest using the provided request and session.
        public convenience init(_ request: @escaping @autoclosure () -> URLRequest,
                                name: String? = nil,
                                updateRequestDetails: ((_ parameters: inout [URLQueryItem]?,
                                                        _ headers: inout [String: String]?,
                                                        _ repeatCount: Int) -> Void)? = nil,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            
            self.init(requestGenerator: .request({ _, _ in return request() }, update: updateRequestDetails),
                      name: name,
                      usingSession: session(),
                      repeatInterval: repeatInterval,
                      repeatHandler: repeatHandler,
                      completionHandler: completionHandler)
        }
        
        /// Create a new WebRequest using the provided request and session.
        public convenience init(_ request: @escaping (_ previousRequest: URLRequest?,
                                                      _ repeatCount: Int) -> URLRequest,
                                name: String? = nil,
                                updateRequestDetails: ((_ parameters: inout [URLQueryItem]?,
                                                        _ headers: inout [String: String]?,
                                                        _ repeatCount: Int) -> Void)? = nil,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            
            self.init(requestGenerator: .request(request, update: updateRequestDetails),
                      name: name,
                      usingSession: session(),
                      repeatInterval: repeatInterval,
                      repeatHandler: repeatHandler,
                      completionHandler: completionHandler)
        }
        
        // Create a new WebRequest using the provided url and session
        public convenience init(_ url: @escaping @autoclosure () -> URL,
                                name: String? = nil,
                                updateRequestDetails: ((_ parameters: inout [URLQueryItem]?,
                                                        _ headers: inout [String: String]?,
                                                        _ repeatCount: Int) -> Void)? = nil,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            self.init(requestGenerator: .url({ _, _ in return url() }, update: updateRequestDetails),
                      name: name,
                      usingSession: session(),
                      repeatInterval: repeatInterval,
                      repeatHandler: repeatHandler,
                      completionHandler: completionHandler)
        }
        
        // Create a new WebRequest using the provided url and session
        public convenience init(_ url: @escaping (_ previousURL: URL?,
                                                  _ repeatCount: Int) -> URL,
                                name: String? = nil,
                                updateRequestDetails: ((_ parameters: inout [URLQueryItem]?,
                                                        _ headers: inout [String: String]?,
                                                        _ repeatCount: Int) -> Void)? = nil,
                                usingSession session: @escaping @autoclosure () -> URLSession,
                                repeatInterval: TimeInterval = RepeatedDataRequestConstants.DEFAULT_REPEAT_INTERVAL,
                                repeatHandler: @escaping (RepeatedDataRequest<T>, DataRequest.Results, Int) throws -> RepeatResults,
                                completionHandler: ((DataRequest.Results, T?, Swift.Error?) -> Void)? = nil) {
            self.init(requestGenerator: .url(url, update: updateRequestDetails),
                      name: name,
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
            self.results = .init(request: self.currentRequest)
            
            // removing any reference to any exture closures
            self.repeatHandler = nil
            self.completionHandlers.withUpdatingLock { r in
                r.handler = nil
            }
        }
        
        /// Register a requset completion handler
        /// - Parameters:
        ///   - handlerID: The unique ID to use when registering the handler.  This ID can be used to remove the handler later.  If the ID was not unique a precondition error will occure
        ///   - handler: The completion handler to be called
        public func registerCompletionHandler(handlerID: String,
                                              handler: @escaping (_ request: RepeatedDataRequest,
                                                                  _ results: DataRequest.Results,
                                                                  _ object: T?,
                                                                  _ error: Swift.Error?) -> Void) {
            
            self.completionHandlers.withUpdatingLock { r in
                if r.handler == nil { r.handler = [:] }
                guard !(r.handler!.keys.contains(handlerID)) else {
                    preconditionFailure("Handler ID Already exists")
                }
                r.handler![handlerID] = handler
            }
        }
        
        /// Register a requset completion handler
        /// - Parameter handler: The completion handler to be called
        /// - Returns: Returns the unique ID for the handler tha  can be used to remove the handle later
        @discardableResult
        public func registerCompletionHandler(handler: @escaping (_ request: RepeatedDataRequest,
                                                                  _ results: DataRequest.Results,
                                                                  _ object: T?,
                                                                  _ error: Swift.Error?) -> Void) -> String {
            let uid = UUID().uuidString
            self.registerCompletionHandler(handlerID: uid, handler: handler)
            return uid
        }
        
        /// Removes a handler
        /// - Parameter id: The unique ID of the handler to remove
        /// - Returns: Returns an indicator if a handler was removed
        @discardableResult
        public func unregisterCompletionHandler(for id: String) -> Bool {
            return self.completionHandlers.withUpdatingLock { r in
                return r.handler?.removeValue(forKey: id) != nil
            }
        }
        
        
        /// Schedule the next request creation on a dispatch queue
        /// - Parameters:
        ///   - deadline: The time when to schedule the creation of the new request. (eg: .now() + ...)
        ///   - queue: The Dispatch Queue to create the new new request on
        private func scheduleNewRequest(deadline: DispatchTime,
                                        in queue: DispatchQueue = .global()) {
            queue.asyncAfter(deadline: deadline) {
                guard self.state == .running else { return }
                
                self.repeatCount += 1
                self.createRequest(repeatIteration: self.repeatCount)
            }
        }
        
        /// Create and execute a request
        /// - Parameter repeatCount: The current repeat count
        private func createRequest(repeatIteration repeatCount: Int) {
            
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
                
                guard let currentSelf = self else { return }
                
                // Empty out links/data for current data request
                if let observer = currentSelf.notificationCenterObserver {
                    // Stop observing old request
                    NotificationCenter.default.removeObserver(observer)
                    currentSelf.notificationCenterObserver = nil
                }
                // Empty old request data
                currentSelf.webRequest?.emptyResultsData()
                currentSelf.webRequest = nil
                
                // Get response error if any
                var err: Swift.Error? = requestResults.error
                var shouldContinue: Bool = true
                var results: T? = nil
                if shouldContinue { //If we are ok to continue so far we should call repeatHandler
                    do {
                        if let f = currentSelf.repeatHandler {
                            //Call repeat handler
                            let r = try f(currentSelf, requestResults, currentSelf.repeatCount)
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
                    currentSelf.scheduleNewRequest(deadline: .now() + currentSelf.repeatInterval)
                    
                } else {
                    
                    currentSelf.results = .init(object: results,
                                                request: requestResults.request,
                                                response: requestResults.response,
                                                error: err ?? requestResults.error)
                    
                    
                    let finishState = (currentSelf.webRequest?.state ?? .completed)
                    let currentState = currentSelf._state
                    currentSelf._state = finishState
                    currentSelf._error = err
                    // We are no longer repeating.  Lets trigger the proper event handlers.
                    currentSelf.triggerStateChange(from: currentState, to: finishState)
                    
                    
                    currentSelf.completionHandlers.withUpdatingLock { r in
                        r.hasCalled = true
                        if let handlers = r.handler?.values {
                            for h in handlers {
                                 currentSelf.callSyncEventHandler {
                                     h(currentSelf, requestResults, results, err)
                                 }
                            }
                        }
                    }
                    
                    
                }
                
                // Empty old request data
                currentSelf.webRequest?.emptyResultsData()
                currentSelf.webRequest = nil
                
                
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
        
        public override func resume() {
            guard self.state == .suspended else { return }
            self._state = .running
            self.triggerStateChange(from: .suspended, to: .running)
            
            if let r = self.webRequest { r.resume() }
            else {
                // Must create sub request
                self.createRequest(repeatIteration: 0)
            }
        }
        
        
        public override func suspend()  {
            guard self.state == .running else { return }
            self._state = .suspended
            self.triggerStateChange(from: .running, to: .suspended)
            
            if let r = self.webRequest { r.suspend() }
            
        }
        
        public override func cancel() {
            let currentState = self.state
            guard currentState == .running || currentState == .suspended else { return }
            self._state = .canceling
            
            let cancelledResults = DataRequest.Results.generateCanceledResults(for: self.currentRequest)
            
            
            self.results = .init(object: nil,
                                 dataResults: cancelledResults)
            
            self.triggerStateChange(from: currentState, to: .canceling)
            
            self.completionHandlers.withUpdatingLock { r in
                guard !r.hasCalled else { return }
                r.hasCalled = true
                
                if let handlers = r.handler?.values {
                    for f in handlers {
                        /// was async
                        self.callSyncEventHandler {
                            f(self, cancelledResults, nil, cancelledResults.error)
                        }
                    }
                }
            }
            
            //Cancel all outstanding requests
            self.cancelRequest()
            
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
            
            guard !self.completionHandlers.value.hasCalled else { return }
            
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
