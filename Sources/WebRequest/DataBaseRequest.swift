//
//  DataBaseRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-28.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif

public extension WebRequest {
    /// Allows for a single data web request
    class DataBaseRequest: WebRequest {
        
        /// Results container for request response
        public struct Results {
            public let request: URLRequest
            public let response: URLResponse?
            public let error: Error?
            public private(set) var data: Data?
            
            /// The original url of the request
            public var originalURL: URL? { return request.url }
            /// The url from the response.   This could differ from the originalURL if there were redirects
            public var currentURL: URL? {
                if let r = response?.url { return r }
                else { return originalURL }
            }
            
            internal var hasResponse: Bool {
                return (self.response != nil || self.error != nil || self.data != nil)
            }
            
            public init(request: URLRequest,
                        response: URLResponse? = nil,
                        error: Error? = nil,
                        data: Data? = nil) {
                self.request = request
                self.response = response
                self.error = error
                self.data = data
            }
            
            /// Allows for clearing of the reponse data.
            /// This can be handy when working with GroupRequests with a lot of data.
            /// That way you can process each request as it comes in and clear the data so its not sitting in memeory until all requests are finished
            internal mutating func emptyData() {
                self.data?.removeAll()
                self.data = nil
            }
            
        }
        
        internal class URLSessionTaskEventHandler: NSObject,
                                                   URLSessionDataDelegate {
            
            
            public var dataBuffer: Data?
            private var hasEventHandlers: Bool = false
            
            public var completionHandler: ((Data?,
                                            URLResponse?,
                                            Error?) -> Void)? = nil
            
            
            public var _urlSessionDidBecomeInvalidWithError: ((URLSession,
                                                               Error?) -> Void)? = nil {
                didSet {
                    self.hasEventHandlers = true
                }
            }
            func urlSession(_ session: URLSession,
                            didBecomeInvalidWithError error: Error?) {
                if let handler = self._urlSessionDidBecomeInvalidWithError {
                    handler(session, error)
                }
            }
            
            public var _urlSessionDidFinishEventsForBackground: ((URLSession) -> Void)? = nil {
                didSet {
                    self.hasEventHandlers = true
                }
            }
            func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
                if let handler = self._urlSessionDidFinishEventsForBackground {
                    handler(session)
                }
            }
            
            
            public var _urlSessionDidCompleteWithError: ((URLSession,
                                                          URLSessionTask,
                                                          Error?) -> Void)? = nil
            internal var _urlSessionWebRequestDidCompleteWithError: ((URLSession,
                                                                         URLSessionTask,
                                                                         Data?,
                                                                         URLResponse?,
                                                                         Error?) -> Void)? = nil
            func urlSession(_ session: URLSession,
                            task: URLSessionTask,
                            didCompleteWithError error: Error?) {
                
                
                if let handler = self._urlSessionDidCompleteWithError {
                    handler(session, task, error)
                }
                if let handler = self._urlSessionWebRequestDidCompleteWithError {
                    handler(session, task, self.dataBuffer, task.response, error)
                }
                
                if let handler = completionHandler {
                    handler(self.dataBuffer, task.response, error)
                }
                self.dataBuffer = nil

            }
            
            public var _urlSessionDidSendBodyData: ((URLSession,
                                                     URLSessionTask,
                                                     Int64,
                                                     Int64,
                                                     Int64) -> Void)? = nil {
                didSet {
                    self.hasEventHandlers = true
                }
            }
            func urlSession(_ session: URLSession,
                            task: URLSessionTask,
                            didSendBodyData bytesSent: Int64,
                            totalBytesSent: Int64,
                            totalBytesExpectedToSend: Int64) {
                if let handler = self._urlSessionDidSendBodyData {
                    handler(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
                }
            }
            
            public var _urlSessionDidReceiveData: ((URLSession,
                                                    URLSessionDataTask,
                                                    Data) -> Void)? = nil {
                didSet {
                    self.hasEventHandlers = true
                }
            }
            func urlSession(_ session: URLSession,
                            dataTask: URLSessionDataTask,
                            didReceive data: Data) {
                
                if self.completionHandler != nil || !self.hasEventHandlers {
                    if self.dataBuffer == nil { self.dataBuffer = Data() }
                    self.dataBuffer?.append(data)
                }
                
                if let handler = self._urlSessionDidReceiveData {
                    handler(session, dataTask, data)
                }
                
                
            }
        }
        
        
        private var task: URLSessionDataTask! = nil
        
        /// Results from the request
        public internal(set) var results: Results
        
        public override var state: WebRequest.State {
            //Some times completion handler gets called even though task state says its still running on linux
            guard self.results.hasResponse else {
                return WebRequest.State(rawValue: self.task.state.rawValue)!
            }
            
            #if _runtime(_ObjC) || swift(>=4.1.4)
             if let e = self.results.error, (e as NSError).code == NSURLErrorCancelled {
                return WebRequest.State.canceling
             } else {
                return WebRequest.State.completed
             }
            #else
             if let e = self.results.error, let nsE = e as? NSError, nsE.code == NSURLErrorCancelled {
                return WebRequest.State.canceling
             } else {
                return WebRequest.State.completed
             }
            #endif
            
            
            //#warning ("This is a warning test")
            
        }
        
        /// The URL request object currently being handled by the request.
        public var currentRequest: URLRequest? { return self.task.currentRequest }
        /// The original request object passed when the request was created.
        public private(set) var originalRequest: URLRequest?
        /// The server’s response to the currently active request.
        public var response: URLResponse? { return self.task.response }
        
        /// An app-provided description of the current request.
        public var webDescription: String? {
            get { return self.task.taskDescription }
            set { self.task.taskDescription = newValue }
        }
        /// An identifier uniquely identifies the task within a given session.
        public var taskIdentifier: Int { return self.task.taskIdentifier }
        
        public override var error: Swift.Error? { return self.task.error }
        
        private let eventDelegate: URLSessionTaskEventHandler
        
        /// The relative priority at which you’d like a host to handle the task, specified as a floating point value between 0.0 (lowest priority) and 1.0 (highest priority).
        public var priority: Float {
            get { return self.task.priority }
            set { self.task.priority = newValue }
        }
        
        #if _runtime(_ObjC)
        /// A representation of the overall request progress
        @available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
        public override var progress: Progress { return self.task.progress }
        #endif
        
        
        
        public var urlSessionDidBecomeInvalidWithError: ((URLSession, Error?) -> Void)? {
            get { return self.eventDelegate._urlSessionDidBecomeInvalidWithError }
            set { self.eventDelegate._urlSessionDidBecomeInvalidWithError = newValue }
        }
        
        
        public var urlSessionDidFinishEventsForBackground: ((URLSession) -> Void)? {
            get { return self.eventDelegate._urlSessionDidFinishEventsForBackground }
            set { self.eventDelegate._urlSessionDidFinishEventsForBackground = newValue }
        }
        
        public var urlSessionDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)? {
            get { return self.eventDelegate._urlSessionDidSendBodyData }
            set { self.eventDelegate._urlSessionDidSendBodyData = newValue }
        }
        
        public var urlSessionDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)? {
            get { return self.eventDelegate._urlSessionDidReceiveData }
            set { self.eventDelegate._urlSessionDidReceiveData = newValue }
        }
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - task: The task executing the request
        ///   - eventDelegate: The delegate used to monitor the task events
        ///   - originalRequest: The original request of the task
        ///   - completionHandler: The call back when done executing
        internal init(_ task: URLSessionDataTask,
                      eventDelegate: URLSessionTaskEventHandler,
                      originalRequest: URLRequest,
                      completionHandler: ((Results) -> Void)? = nil) {
            self.task = task
            self.eventDelegate = eventDelegate
            self.originalRequest = originalRequest
            self.results = Results(request: originalRequest)
            super.init()
            self.eventDelegate._urlSessionWebRequestDidCompleteWithError = { _, _, data, response, error in
                self.results = Results(request: self.originalRequest!,
                                       response: response,
                                       error: error,
                                       data: data)
                self.triggerStateChange(.completed)
            }
            if let ch = completionHandler {
                eventDelegate.completionHandler = { data, response, error in
                    /// Was async
                    self.callSyncEventHandler { ch(self.results) }
                }
            }
            
        }
        
        /// Resumes the request, if it is suspended.
        public override func resume() {
            super.resume()
            self.task.resume()
        }
        
        /// Temporarily suspends a request.
        public override func suspend() {
            super.suspend()
            self.task.suspend()
        }
        
        /// Cancels the request
        public override func cancel() {
            
            //Setup results for cancelled requests
            if !self.results.hasResponse {
                self.results = Results(request: self.originalRequest!,
                                       response: nil,
                                       error: WebRequest.createCancelationError(forURL: self.originalRequest!.url!),
                                       data: nil)
            }
            
            super.cancel()
            self.task.cancel()
            
        }
        
        /// Allows for clearing of the reponse data.
        /// This can be handy when working with GroupRequests with a lot of data.
        /// That way you can process each request as it comes in and clear the data so its not sitting in memeory until all requests are finished
        public func emptyResultsData() {
            self.results.emptyData()
        }
    }
}
