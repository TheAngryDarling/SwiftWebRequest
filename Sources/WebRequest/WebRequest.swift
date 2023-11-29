import Foundation
import Dispatch

/// Base class for a web request.
open class WebRequest: NSObject {
    
    public struct UserInfoKeys {
        public static let parent = "org.webrequest.WebRequest.parent"
    }
    
    /// Constants for determining the current state of a request.
    public enum State: Int {
        /// The request is currently being serviced by the session.
        /// A task in this state is subject to the request and resource timeouts specified in the session configuration object.
        case running = 0
        /// The request was suspended by the app.
        /// No further processing takes place until it is resumed. A request in this state is not subject to timeouts.
        case suspended = 1
        /// The request has received a cancel message.
        ///The delegate may or may not have received a urlSession(_:task:didCompleteWithError:) message yet. A request in this state is not subject to timeouts.
        case canceling = 2
        /// The request has completed (without being canceled), and the request's delegate receives no further callbacks.
        /// If the request completed successfully, the request's error property is nil. Otherwise, it provides an error object that tells what went wrong. A request in this state is not subject to timeouts.
        case completed = 3
    }
    
    public enum ChangeState {
        /// The request was suspended by the app.
        /// No further processing takes place until it is resumed. A request in this state is not subject to timeouts.
        case suspended
        /// The request is resuming for the first time
        /// The task will have a state of running when checked
        case starting
        /// The request is currently being serviced by the session.
        /// A task in this state is subject to the request and resource timeouts specified in the session configuration object.
        case running
        /// The request has received a cancel message.
        ///The delegate may or may not have received a urlSession(_:task:didCompleteWithError:) message yet. A request in this state is not subject to timeouts.
        case canceling
        /// The request has completed (without being canceled), and the request's delegate receives no further callbacks.
        /// If the request completed successfully, the request's error property is nil. Otherwise, it provides an error object that tells what went wrong. A request in this state is not subject to timeouts.
        case completed
        
        /// Create a State object representing the change state
        internal var state: State {
            switch self {
                case .suspended: return .suspended
                case .starting, .running: return .running
                case .canceling: return .canceling
                case .completed: return .completed
            }
        }
        /// Create a ChangeState object from a State object
        ///
        /// If the state is running and alreadyStarted is false then the change state will be starting
        ///
        /// - Parameters:
        ///   - state: The state to create from
        ///   - alreadyStarted: Indicator if the requet was already started
        public init(_ state: State, alreadyStarted: Bool) {
            switch state {
                case .suspended: self = .suspended
                case .running:
                    if !alreadyStarted { self = .starting }
                    else { self = .running }
                case .canceling: self = .canceling
                case .completed: self = .completed
            }
        }
        
        /// Create a ChangeState object from a State object
        /// - Parameter state: The state to create from
        public init(_ state: State) {
            self.init(state, alreadyStarted: true)
        }
        
    }
    
    /// Callback handler for simple events that only send the web request object
    public typealias SimpleEventCallback = (WebRequest) -> Void
    /// State Change callback handler that send the web request and the new state
    public typealias StateChangeEventCallback = (WebRequest, WebRequest.State) -> Void
    /// State Change Event handler that signals when the state of a web request changes
    public typealias StateChangeHandler = (WebRequest,WebRequest.State, WebRequest.ChangeState) -> Void
    
    /// Synchronized resource around indicator if the web request has started yet
    private let _hasStarted: ResourceLock<Bool> = .init(resource: false)
    /// Indicator if the web request has started yet
    public var hasStarted: Bool { return self._hasStarted.value }
    
    /// Synchronized resource indicator if the web request is running
    private let _isRunning: ResourceLock<Bool> = .init(resource: false)
    /// Indicator if the web request is running (request has started but has not been completed)
    public var isRunning: Bool { return self._isRunning.value }
    
    /// Synchronized resource indicator if the web request has completed
    private let _hasCompleted: ResourceLock<Bool> = .init(resource: false)
    /// Inidcator if the current web request has completed
    public var hasCompleted: Bool { return self._hasCompleted.value }
    
    /// The current state of the requset
    public var state: State { fatalError("Not Impelemented") }
    
    
    #if _runtime(_ObjC)
    /// The progress of the request
    @available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open var progress: Progress { fatalError("Not Impelemented") }
    #endif
    
    /// The error of the resposne
    open var error: Swift.Error? { fatalError("Not Impelemented")  }
    
    /// Added eventHandlerQueue to ensure that events are triggered sequentially
    private let eventHandlerQueue: DispatchQueue = DispatchQueue(label: "org.webrequest.WebRequest.EventHandler.Queue")
    
    /// Event handler that gets triggered when the request first starts
    public var requestStarted: (SimpleEventCallback)? = nil
    /// Event handler that gets triggered when the request get resumed
    public var requestResumed: (SimpleEventCallback)? = nil
    /// Event handler that gets triggered when the request get suspended
    public var requestSuspended: (SimpleEventCallback)? = nil
    /// Event handler that gets triggered when the request get cancelled
    public var requestCancelled: (SimpleEventCallback)? = nil
    /// Event handler that gets triggered when the request is completed
    public var requestCompleted: (SimpleEventCallback)? = nil
    
    /// Event handler that gets triggered when the requests state changes
    public var requestStateChanged: (StateChangeEventCallback)? = nil
    /// Synchronized dictionary of callbacks to execute when web request state has changed
    private var requestStateChangedHandlers: ResourceLock<[String: StateChangeHandler]> = .init(resource: [:])
    
    /// Synchronized array of callbacks to execute when web request is about to deinit
    private var deinitHandlers: ResourceLock<[String: SimpleEventCallback]> = .init(resource: [:])
    
    /// An object for users to store any additional information regarding the request
    private var _userInfo: ResourceLock<[String: Any]> = .init(resource: [:])
    public var userInfo: [String: Any]  {
        get {
            return self._userInfo.value
        }
        set {
            self._userInfo.value = newValue
        }
    }
    
    /// Synchronized array of callbacks to execute when web request has completed
    private var waitCompletionCallbacks: ResourceLock<[() -> Void]> = .init(resource: [])
    /// Synchronized dictionary of callbacks to execute when web request has completed
    private var simpleCompletionHandlers: ResourceLock<[String:SimpleEventCallback]> = .init(resource: [:])
    
    /// A unique UUID for this request object
    public let uid: String
    /// Custom Name identifing this request
    public let name: String?
    
    /// The date / time the request started
    private var requestStartTime: Date? = nil
    /// the date / time the request ended
    private var requestEndTime: Date? = nil
    /// Returns the duration from the start of the request to the completion.
    /// If the request has not completed this will return nil
    public var requestCompleteDuration: TimeInterval? {
        guard let stRD = self.requestStartTime,
              let edRD = self.requestEndTime else {
            return nil
        }
        return edRD.timeIntervalSince(stRD).magnitude
    }
    /// Returns the duration since the start of the request.
    /// If the request has not started then this will return 0
    public var requestCurrentDuration: TimeInterval {
        guard let stRD = self.requestStartTime else {
            return 0.0
        }
        return Date().timeIntervalSince(stRD).magnitude
    }
    
    /// Object used to synchronize access to triggerStateChange function
    private let stateChangeLock = NSLock()
    
    
    internal init(name: String?) {
        self.uid = UUID().uuidString
        self.name = name
    }
    deinit {
        self.deinitHandlers.withUpdatingLock { handlers in
            // execute all deinit handlers prior to any other cleanup
            // so all object value are still available
            for handler in handlers.values {
                handler(self)
            }
            handlers = [:]
        }
        // if we loose reference we cancel the requset?
        if self._isRunning.value {
            self.cancel()
        }
        self.userInfo.removeAll()
        
        // removing any reference to any exture closures
        self.requestStarted = nil
        self.requestResumed = nil
        self.requestSuspended = nil
        self.requestCancelled = nil
        self.requestCompleted = nil
        self.requestStateChanged = nil
        
        self.waitCompletionCallbacks.withUpdatingLock { waitCallbacks in
            for waitEvent in waitCallbacks {
                waitEvent()
            }
            waitCallbacks = []
        }
        self.requestStateChangedHandlers.withUpdatingLock { dict in
            dict = [:]
        }
    }
    
    internal func generateNotificationUserInfoFor(_ notificationName: Notification.Name,
                                                  fromState: State,
                                                  toState: ChangeState) -> [AnyHashable : Any]? {
        guard (notificationName == Notification.Name.WebRequest.StateChanged ||
                notificationName == Notification.Name.WebRequest.StateChangedChild) else {
                return nil
        }
        
        return [
            Notification.Name.WebRequest.Keys.State: toState.state,
            Notification.Name.WebRequest.Keys.ToState: toState,
            Notification.Name.WebRequest.Keys.FromState: fromState,
        ]
    }
    
    private func sendNotification(_ notificationName: Notification.Name,
                                  fromState: WebRequest.State,
                                  toState: WebRequest.ChangeState) {
        let nc = NotificationCenter.default
        nc.post(name: notificationName,
                object: self,
                userInfo: self.generateNotificationUserInfoFor(notificationName,
                                                               fromState: fromState,
                                                               toState: toState))
    }
    
    internal func _triggerStateChange(from fromState: WebRequest.State,
                                      to toState: WebRequest.State,
                                      file: StaticString,
                                      line: UInt) {
        // synchronize access to this method
        self.stateChangeLock.lock()
        defer { self.stateChangeLock.unlock() }
        
        guard fromState != toState else {
            return
        }
        let toStateChange = ChangeState(toState, alreadyStarted: self.hasStarted)
        
        
        if let handler = self.requestStateChanged {
            callAsyncEventHandler {
                handler(self, toState)
            }
        }
        
        // Lets get a copy of all state change handlers
        let stateChangeHandlers = self.requestStateChangedHandlers.withUpdatingLock { handlers in
            return handlers.values
        }
        // Lets trigger the registered state handlers
        for handler in stateChangeHandlers {
            self.callAsyncEventHandler {
            //self.callSyncEventHandler {
                handler(self, fromState, toStateChange)
            }
        }
        
        
        
        var triggerDoneGroup: Bool = false
        let event: ((WebRequest) -> Void)? = {
            switch toState {
                case .completed:
                    self.requestEndTime = Date()
                    self.sendNotification(Notification.Name.WebRequest.DidComplete,
                                          fromState: fromState,
                                          toState: toStateChange)
                    // flag that will eventually release any wait calls
                    triggerDoneGroup = true
                    // change running indicator to false
                    self._isRunning.value = false
                    // change has completed indicator to true
                    self._hasCompleted.value = true
                    return self.requestCompleted
                case .canceling:
                    self.requestEndTime = Date()
                    self.sendNotification(Notification.Name.WebRequest.DidCancel,
                                          fromState: fromState,
                                          toState: toStateChange)
                    // flag that will eventuall release any wait calls
                    triggerDoneGroup = true
                    // change running indicator to false
                    self._isRunning.value = false
                    // change has completed indicator to true
                    self._hasCompleted.value = true
                    return self.requestCancelled
                case .suspended:
                    self.sendNotification(Notification.Name.WebRequest.DidSuspend,
                                          fromState: fromState,
                                          toState: toStateChange)
                    return self.requestSuspended
                case .running:
                    var notificationName = Notification.Name.WebRequest.DidResume
                    var rtnEventFnc = self.requestResumed
                    if !self._hasStarted.valueThenSet(to: true) {
                        self.requestStartTime = Date()
                        self.requestEndTime = nil
                        
                        notificationName = Notification.Name.WebRequest.DidStart
                        // change running indicator to true
                        self._isRunning.value = true
                        // change has completed indicator to false
                        self._hasCompleted.value = false
                        rtnEventFnc = self.requestStarted
                    }
                    self.sendNotification(notificationName,
                                          fromState: fromState,
                                          toState: toStateChange)
                    return rtnEventFnc
            }
        }()
        
        
        if let handler = event {
            self.callAsyncEventHandler {
                handler(self)
            }
        }
        
        self.sendNotification(Notification.Name.WebRequest.StateChanged,
                              fromState: fromState,
                              toState: toStateChange)
        if triggerDoneGroup {
            
            self.simpleCompletionHandlers.withUpdatingLock { r in
                for handler in r.values {
                    handler(self)
                }
                r = [:]
            }
            self.waitCompletionCallbacks.withUpdatingLock { r in
                // trigger wait events
                for waitEvent in r {
                    waitEvent()
                }
                r = []
            }
        }
    }
    
    #if swift(>=5.3)
    internal func triggerStateChange(from fromState: WebRequest.State,
                                     to toState: WebRequest.State,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) {
        self._triggerStateChange(from: fromState, to: toState, file: file, line: line)
    }
    #else
    internal func triggerStateChange(from fromState: WebRequest.State,
                                     to toState: WebRequest.State,
                                     file: StaticString = #file,
                                     line: UInt = #line) {
        self._triggerStateChange(from: fromState, to: toState, file: file, line: line)
    }
    #endif

    
    
    
    internal func callAsyncEventHandler(handler: @escaping () -> Void) {
        eventHandlerQueue.async {
            #if _runtime(_ObjC) || swift(>=4.1)
            let currentThreadName = Thread.current.name
            defer { Thread.current.name = currentThreadName }
            if Thread.current.name == nil || Thread.current.name == "" { Thread.current.name = "WebRequest.Events" }
            #endif
            
            handler()
        }
    }
    
    internal func callSyncEventHandler(handler: @escaping () -> Void) {
        eventHandlerQueue.sync {
            #if _runtime(_ObjC) || swift(>=4.1)
            let currentThreadName = Thread.current.name
            defer { Thread.current.name = currentThreadName }
            if Thread.current.name == nil || Thread.current.name == "" { Thread.current.name = "WebRequest.Events" }
            #endif
            
            handler()
        }
    }
    
    /// Register a state changed handler
    /// - Parameters:
    ///   - handlerID: The unique ID to use when registering the handler.  This ID can be used to remove the handler later.  If the ID was not unique a precondition error will occure
    ///   - handler: The state change handler to be called
    public func registerStateChangedHandler(handlerID: String,
                                            handler: @escaping StateChangeHandler) {
        
        self.requestStateChangedHandlers.withUpdatingLock { dict in
            guard !dict.keys.contains(handlerID) else {
                preconditionFailure("Handler ID Already exists")
            }
            dict[handlerID] = handler
        }
    }
    
    /// Register a state changed handler
    /// - Parameter handler: The state change handler to be called
    /// - Returns: Returns the unique ID for the handler tha  can be used to remove the handle later
    @discardableResult
    public func registerStateChangedHandler(handler: @escaping StateChangeHandler) -> String {
        let uid = UUID().uuidString
        self.registerStateChangedHandler(handlerID: uid, handler: handler)
        return uid
    }
    
    /// Removes a handler
    /// - Parameter id: The unique ID of the handler to remove
    /// - Returns: Returns an indicator if a handler was removed
    @discardableResult
    public func unregisterStateChangedHandler(for id: String) -> Bool {
        return self.requestStateChangedHandlers.withUpdatingLock { dict in
            return dict.removeValue(forKey: id) != nil
        }
    }
    
    /// Register a deinit handler
    /// - Parameters:
    ///   - handlerID: The unique ID to use when registering the handler.  This ID can be used to remove the handler later.  If the ID was not unique a precondition error will occure
    ///   - handler: The deinit handler to be called
    public func registerDeinitHandler(handlerID: String,
                                      handler: @escaping SimpleEventCallback) {
        
        self.deinitHandlers.withUpdatingLock { dict in
            guard !dict.keys.contains(handlerID) else {
                preconditionFailure("Handler ID Already exists")
            }
            dict[handlerID] = handler
        }
    }
    
    /// Register a state changed handler
    /// - Parameter handler: The state change handler to be called
    /// - Returns: Returns the unique ID for the handler tha  can be used to remove the handle later
    @discardableResult
    public func registerDeinitHandler(handler: @escaping SimpleEventCallback) -> String {
        let uid = UUID().uuidString
        self.registerDeinitHandler(handlerID: uid, handler: handler)
        return uid
    }
    
    /// Removes a handler
    /// - Parameter id: The unique ID of the handler to remove
    /// - Returns: Returns an indicator if a handler was removed
    @discardableResult
    public func unregisterDeinitHandler(for id: String) -> Bool {
        return self.deinitHandlers.withUpdatingLock { dict in
            return dict.removeValue(forKey: id) != nil
        }
    }
    
    /// Register a requset simple completion handler
    /// - Parameters:
    ///   - handlerID: The unique ID to use when registering the handler.  This ID can be used to remove the handler later.  If the ID was not unique a precondition error will occure
    ///   - handler: The completion handler to be called
    public func registerSimpleCompletionHandler(handlerID: String,
                                                handler: @escaping SimpleEventCallback) {
        
        self.simpleCompletionHandlers.withUpdatingLock { r in
            guard !(r.keys.contains(handlerID)) else {
                preconditionFailure("Handler ID Already exists")
            }
            r[handlerID] = handler
        }
    }
    
    /// Register a requset simple completion handler
    /// - Parameter handler: The completion handler to be called
    /// - Returns: Returns the unique ID for the handler tha  can be used to remove the handle later
    @discardableResult
    public func registerSimpleCompletionHandler(handler: @escaping SimpleEventCallback) -> String {
        let uid = UUID().uuidString
        self.registerSimpleCompletionHandler(handlerID: uid, handler: handler)
        return uid
    }
    
    /// Removes a handler
    /// - Parameter id: The unique ID of the handler to remove
    /// - Returns: Returns an indicator if a handler was removed
    @discardableResult
    public func unregisterSimpleCompletionHandler(for id: String) -> Bool {
        return self.simpleCompletionHandlers.withUpdatingLock { r in
            return r.removeValue(forKey: id) != nil
        }
    }
    
    
    
    /// Starts/resumes the task, if it is suspended.
    /// Returns: Bool indicator if the call was successful or not
    open func resume() {
        guard type(of: self) != WebRequest.self else { fatalError("Not Impelemented") }
        guard self.state == .suspended else { return }
        
        self.triggerStateChange(from: .suspended, to: .running)
        
    }
    /// Temporarily suspends a task.
    /// Returns: Bool indicator if the call was successful or not
    open func suspend() {
        guard type(of: self) != WebRequest.self else { fatalError("Not Impelemented") }
        guard self.state == .running else { return }
        self.triggerStateChange(from: .running, to: .suspended)
    }
    /// Cancels the task
    /// Returns: Bool indicator if the call was successful or not 
    open func cancel() {
        guard type(of: self) != WebRequest.self else { fatalError("Not Impelemented") }
        let currentState = self.state
        guard currentState == .running || currentState == .suspended else { return }
        self.triggerStateChange(from: currentState, to: .canceling)
    }
    
    /// Wait until request is completed.  There is no guarentee that the completion events were called before this method returns
    public func waitUntilComplete() {
        // Make sure the request has started before waiting
        
        var ds: DispatchSemaphore? = nil
        self._hasCompleted.withUpdatingLock { hasCompleted in
            guard !hasCompleted else { return }
            ds = DispatchSemaphore(value: 0)
            self.waitCompletionCallbacks.withUpdatingLock { waitCallbacks in
                waitCallbacks.append {
                    ds?.signal()
                }
            }
        }
        ds?.wait()
    }
    
    /// Wait until request complets OR timeout has occured
    /// - Parameter timeout: The latest time to wait for a group to complete.
    /// - Returns: A result value indicating whether the method returned due to a timeout.
    @discardableResult
    public func waitUntilComplete(timeout: DispatchTime) -> DispatchTimeoutResult {
        // Make sure the request has started before waiting
        var ds: DispatchSemaphore? = nil
        self._hasCompleted.withUpdatingLock { hasCompleted in
            guard !hasCompleted else { return }
            ds = DispatchSemaphore(value: 0)
            self.waitCompletionCallbacks.withUpdatingLock { waitCallbacks in
                waitCallbacks.append {
                    ds?.signal()
                }
            }
        }
        return ds?.wait(timeout: timeout) ?? .success
    }
    
    /// Wait until request complets OR timeout has occured
    /// - Parameters:
    ///   - timeout: The latest time to wait for a group to complete.
    ///   - onTimeout: The callback to execute IF the wait timed out
    public func waitUntilCompleteOnTimeOut(timeout: DispatchTime, onTimeout: () -> Void) {
        if self.waitUntilComplete(timeout: timeout) == .timedOut {
            onTimeout()
        }
    }
    
    /// Wait until request complets OR timeout has occured
    /// - Parameters:
    ///   - timeout: The latest time to wait for a group to complete.
    ///   - onSuccess: The callback to execute IF the wait completed successfully
    public func waitUntilCompleteOnSuccess(timeout: DispatchTime, onSuccess: () -> Void) {
        if self.waitUntilComplete(timeout: timeout) == .success {
            onSuccess()
        }
    }
    
    internal static func createCancelationError(forURL url: URL) -> Error {
        #if _runtime(_ObjC)
        var uInfo: [String: Any] = [:]
        uInfo[NSURLErrorFailingURLStringErrorKey] = "\(url)"
        uInfo[NSURLErrorFailingURLErrorKey] = url
        uInfo[NSLocalizedDescriptionKey] = "cancelled"
        return  NSError(domain: "NSURLErrorDomain", code: NSURLErrorCancelled, userInfo: uInfo)
        #else
        return URLError(_nsError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil))
        #endif
    }
}

// Providing internal autoreleasepool to not conflict with
// external resources
internal extension WebRequest {
    #if _runtime(_ObjC)
    static func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
        return try ObjectiveC.autoreleasepool(invoking: body)
    }
    #else
    static func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
        return try body()
    }
    #endif
}

