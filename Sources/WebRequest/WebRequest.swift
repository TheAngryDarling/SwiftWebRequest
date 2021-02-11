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
        // The request was suspended by the app.
        /// No further processing takes place until it is resumed. A request in this state is not subject to timeouts.
        case suspended = 1
        // The request has received a cancel message.
        ///The delegate may or may not have received a urlSession(_:task:didCompleteWithError:) message yet. A request in this state is not subject to timeouts.
        case canceling = 2
        // The request has completed (without being canceled), and the request's delegate receives no further callbacks.
        /// If the request completed successfully, the request's error property is nil. Otherwise, it provides an error object that tells what went wrong. A request in this state is not subject to timeouts.
        case completed = 3
    }
    
    private var hasStarted: Bool = false
    
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
    public var requestStarted: ((WebRequest) -> Void)? = nil
    /// Event handler that gets triggered when the request get resumed
    public var requestResumed: ((WebRequest) -> Void)? = nil
    /// Event handler that gets triggered when the request get suspended
    public var requestSuspended: ((WebRequest) -> Void)? = nil
    /// Event handler that gets triggered when the request get cancelled
    public var requestCancelled: ((WebRequest) -> Void)? = nil
    /// Event handler that gets triggered when the request is completed
    public var requestCompleted: ((WebRequest) -> Void)? = nil
    
    /// Event handler that gets triggered when the requests state changes
    public var requestStateChanged: ((WebRequest, WebRequest.State) -> Void)? = nil
    
    /// An object for users to store any additional information regarding the request
    public var userInfo: [String: Any] = [:]
    
    private let requestWorkingDispatchGroup = DispatchGroup()
    private var hasAlreadyLeftWorkGroup: Bool = false
    
    /// A unique UUID for this request object
    public let uid: String
    
    internal func triggerStateChange(_ state: WebRequest.State) {
        if let handler = requestStateChanged {
            callAsyncEventHandler {
                handler(self, state)
            }
        }
        let event: ((WebRequest) -> Void)? = {
            switch state {
                case .completed:
                    NotificationCenter.default.post(name: Notification.Name.WebRequest.DidComplete, object: self)
                    eventHandlerQueue.sync {
                        if !hasAlreadyLeftWorkGroup {
                            hasAlreadyLeftWorkGroup = true
                            requestWorkingDispatchGroup.leave()
                        }
                    }
                    return self.requestCompleted
                case .canceling:
                    NotificationCenter.default.post(name: Notification.Name.WebRequest.DidCancel, object: self)
                    eventHandlerQueue.sync {
                        if !hasAlreadyLeftWorkGroup {
                            hasAlreadyLeftWorkGroup = true
                            requestWorkingDispatchGroup.leave()
                        }
                    }
                    return self.requestCancelled
                case .suspended:
                    NotificationCenter.default.post(name: Notification.Name.WebRequest.DidSuspend, object: self)
                    return self.requestSuspended
                case .running:
                    let started: Bool = eventHandlerQueue.sync {
                        let rtn: Bool = self.hasStarted
                        if !rtn { self.hasStarted = true }
                        
                        return rtn
                    }
                    if !started {
                        hasAlreadyLeftWorkGroup = false
                        requestWorkingDispatchGroup.enter()
                        NotificationCenter.default.post(name: Notification.Name.WebRequest.DidStart, object: self)
                        return self.requestStarted
                    } else {
                        NotificationCenter.default.post(name: Notification.Name.WebRequest.DidResume, object: self)
                        return self.requestResumed
                    }
            }
        }()
        
        
        if let handler = event {
            callAsyncEventHandler {
                handler(self)
            }
        }
        
        NotificationCenter.default.post(name: Notification.Name.WebRequest.StateChanged,
                                        object: self,
                                        userInfo: [Notification.Name.WebRequest.Keys.State: state])
        
    }
    
    internal override init() {
        self.uid = UUID().uuidString
    }
    deinit {
        self.userInfo.removeAll()
    }
    
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
    
    /// Starts/resumes the task, if it is suspended.
    open func resume() {
        guard type(of: self) != WebRequest.self else { fatalError("Not Impelemented") }
        guard self.state == .suspended else { return }
        
        self.triggerStateChange(.running)
        
    }
    /// Temporarily suspends a task.
    open func suspend() {
        guard type(of: self) != WebRequest.self else { fatalError("Not Impelemented") }
        guard self.state == .running else { return }
        self.triggerStateChange(.suspended)
    }
    /// Cancels the task
    open func cancel() {
        guard type(of: self) != WebRequest.self else { fatalError("Not Impelemented") }
        guard self.state == .running || self.state == .suspended else { return }
        self.triggerStateChange(.canceling)
    }
    
    /// Wait until request is completed.  There is no guarentee that the completion events were called before this method returns
    public func waitUntilComplete() {
         self.requestWorkingDispatchGroup.wait()
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

