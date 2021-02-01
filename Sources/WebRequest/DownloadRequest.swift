//
//  DownloadRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-26.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif

public extension WebRequest {
    /// Allows for a single download web request
    class DownloadRequest: WebRequest {
        
        
        
        /// Results container for request response
        public struct Results {
            public let request: URLRequest
            public let response: URLResponse?
            public let error: Error?
            public private(set) var location: URL?
            
            /// The original url of the request
            public var originalURL: URL? { return request.url }
            /// The url from the response.   This could differ from the originalURL if there were redirects
            public var currentURL: URL? {
                if let r = response?.url { return r }
                else { return originalURL }
            }
            
            internal var hasResponse: Bool {
                return (self.response != nil || self.error != nil || self.location != nil)
            }
            
            
            public init(request: URLRequest, response: URLResponse? = nil, error: Error? = nil, location: URL? = nil) {
                self.request = request
                self.response = response
                self.error = error
                self.location = location
            }
            
        }
        
        private class URLSessionTaskEventHandlerBase: NSObject {
            private var url: URL?
            public var completionHandler: ((URL?, URLResponse?, Error?) -> Void)? = nil
            
            public var _urlSessionDidBecomeInvalidWithError: ((URLSession, Error?) -> Void)? = nil
            public var _urlSessionDidFinishEventsForBackground: ((URLSession) -> Void)? = nil
            public var _urlSessionDidCompleteWithError: ((URLSession,
                                                          URLSessionTask,
                                                          Error?) -> Void)? = nil
            public var _urlSessionDidSendBodyData: ((URLSession,
                                                     URLSessionTask,
                                                     Int64,
                                                     Int64,
                                                     Int64) -> Void)? = nil
            public var _urlSessionDidFinishDownloadingTo: ((URLSession,
                                                            URLSessionTask,
                                                            URL) -> Void)? = nil
            public var _urlSessionDidResumeAtOffset: ((URLSession,
                                                       URLSessionTask,
                                                       Int64,
                                                       Int64) -> Void)? = nil
            public var _urlSessionDidWriteData: ((URLSession,
                                                  URLSessionTask,
                                                  Int64,
                                                  Int64,
                                                  Int64) -> Void)? = nil
        }
        
        private class URLSessionDataTaskEventHandler: URLSessionTaskEventHandlerBase,
                                                      URLSessionDataDelegate {
            
            
            /// Unique temp file
            let uniqueTempFileURL = URL(fileURLWithPath: NSTemporaryDirectory(),
                                        isDirectory: true)
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("tmp")
            
            var totalBytesWritten: Int64 = 0
            
            func urlSession(_ session: URLSession,
                            didBecomeInvalidWithError error: Error?) {
                if let handler = self._urlSessionDidBecomeInvalidWithError {
                    handler(session, error)
                }
                
                //print("Removing download file didBecomeInvalidWithError")
                try? FileManager.default.removeItem(at: self.uniqueTempFileURL)
            }
            
            func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
                if let handler = self._urlSessionDidFinishEventsForBackground {
                    handler(session)
                }
                //print("Removing download file forBackgroundURLSession")
                try? FileManager.default.removeItem(at: self.uniqueTempFileURL)
            }
            
            
            func urlSession(_ session: URLSession,
                            task: URLSessionTask,
                            didCompleteWithError error: Error?) {
                
                
                if let handler = self._urlSessionDidFinishDownloadingTo,
                   FileManager.default.fileExists(atPath: self.uniqueTempFileURL.path) {
                    handler(session, task, self.uniqueTempFileURL)
                }
                if let handler = self._urlSessionDidCompleteWithError {
                    handler(session, task, error)
                }
                
                if let handler = self.completionHandler {
                    var url: URL? = nil
                    if FileManager.default.fileExists(atPath: self.uniqueTempFileURL.path) {
                        url = self.uniqueTempFileURL
                    }
                    handler(url, task.response, error)
                }
                
                //print("Removing download file didCompleteWithError")
                try? FileManager.default.removeItem(at: self.uniqueTempFileURL)

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
            
            func urlSession(_ session: URLSession,
                            dataTask: URLSessionDataTask,
                            didReceive data: Data) {
                
                if FileManager.default.fileExists(atPath: self.uniqueTempFileURL.path) {
                    do {
                        let fileHandle = try FileHandle(forWritingTo: self.uniqueTempFileURL)
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                        
                    } catch {
                        /// Not sure hot to error handle here
                        dataTask.cancel()
                    }
                    
                } else {
                    do {
                        try data.write(to: self.uniqueTempFileURL,
                                       options: .atomic)
                    } catch {
                        /// Not sure hot to error handle here
                        dataTask.cancel()
                    }
                }
                let bitesWriten = Int64(data.count)
                self.totalBytesWritten += bitesWriten
                
                if let handler = self._urlSessionDidWriteData {
                    var expectedBytesWritten: Int64 = NSURLSessionTransferSizeUnknown
                    if let response = dataTask.response,
                       let httpResponse = response as? HTTPURLResponse,
                       let anyContentLength = httpResponse.allHeaderFields["Content-Length"],
                       let strContentLength = anyContentLength as? String,
                       let intConentLength = Int64(strContentLength) {
                        expectedBytesWritten = intConentLength
                    }
                    
                    handler(session,
                            dataTask,
                            bitesWriten,
                            self.totalBytesWritten,
                            expectedBytesWritten)
                }
            }
            
        }
        
        private class URLSessionDownloadTaskEventHandler: URLSessionTaskEventHandlerBase,
                                                          URLSessionDownloadDelegate {
            
            
            private var url: URL?
            func urlSession(_ session: URLSession,
                            didBecomeInvalidWithError error: Error?) {
                if let handler = self._urlSessionDidBecomeInvalidWithError {
                    handler(session, error)
                }
            }
            
            func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
                if let handler = self._urlSessionDidFinishEventsForBackground {
                    handler(session)
                }
            }
            
            
            func urlSession(_ session: URLSession,
                            task: URLSessionTask,
                            didCompleteWithError error: Error?) {
                
                
                if let handler = self._urlSessionDidCompleteWithError {
                    handler(session, task, error)
                }
                
                if let handler = self.completionHandler {
                    handler(url, task.response, error)
                    self.url = nil
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
            
            func urlSession(_ session: URLSession,
                            downloadTask: URLSessionDownloadTask,
                            didFinishDownloadingTo location: URL) {
                self.url = location
                if let handler = self._urlSessionDidFinishDownloadingTo {
                    handler(session, downloadTask, location)
                }
            }
            
            func urlSession(_ session: URLSession,
                            downloadTask: URLSessionDownloadTask,
                            didResumeAtOffset fileOffset: Int64,
                            expectedTotalBytes: Int64) {
                if let handler = self._urlSessionDidResumeAtOffset {
                    handler(session, downloadTask, fileOffset, expectedTotalBytes)
                }
            }
            
            func urlSession(_ session: URLSession,
                            downloadTask: URLSessionDownloadTask,
                            didWriteData bytesWritten: Int64,
                            totalBytesWritten: Int64,
                            totalBytesExpectedToWrite: Int64) {
                if let handler = self._urlSessionDidWriteData {
                    handler(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
                }
            }
        }
        
        
        private var task: URLSessionTask! = nil
        
        /// Results from the request
        public private(set) var results: Results
        
        
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
        
        private let eventDelegate: URLSessionTaskEventHandlerBase
        
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
        
        public var urlSessionDidFinishDownloadingTo: ((URLSession, URLSessionTask, URL) -> Void)? {
            get { return self.eventDelegate._urlSessionDidFinishDownloadingTo }
            set { self.eventDelegate._urlSessionDidFinishDownloadingTo = newValue }
        }
        
        public var urlSessionDidResumeAtOffset: ((URLSession, URLSessionTask, Int64, Int64) -> Void)? {
            get { return self.eventDelegate._urlSessionDidResumeAtOffset }
            set { self.eventDelegate._urlSessionDidResumeAtOffset = newValue }
        }
        
        public var urlSessionDidWriteData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)? {
            get { return self.eventDelegate._urlSessionDidWriteData }
            set { self.eventDelegate._urlSessionDidWriteData = newValue }
        }
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - session: The URL Session to copy the configuration/queue from
        public init(_ request: @autoclosure () -> URLRequest,
                    usingSession session: @autoclosure () -> URLSession) {
            let req = request()
            self.originalRequest = req
            
            self.results = Results(request: req)
            #if swift(>=5.3) || _runtime(_ObjC)
            let delegate = URLSessionDownloadTaskEventHandler()
            self.eventDelegate = delegate
            #else
            let delegate = URLSessionDataTaskEventHandler()
            self.eventDelegate = delegate
            #endif
            super.init()
            let originalSession = session()
            
            let session = URLSession(configuration: originalSession.configuration,
                                     delegate: delegate,
                                     delegateQueue: originalSession.delegateQueue)
            
            #if swift(>=5.3) || _runtime(_ObjC)
            self.task = session.downloadTask(with: req)
            #else
            self.task = session.dataTask(with: req)
            #endif
            
            self.eventDelegate._urlSessionDidCompleteWithError = { _, _, _ in
                self.triggerStateChange(.completed)
            }
            
        }
        
        /// Create a new WebRequest using the provided url and session
        ///
        /// - Parameters:
        ///   - url: The url to request
        ///   - session: The URL Session to copy the configuration/queue from
        public convenience init(_ url: @autoclosure () -> URL,
                                usingSession session: @autoclosure () -> URLSession) {
            self.init(URLRequest(url: url()), usingSession: session())
        }
        
        /// Create a new WebRequest using the provided requset and session. and call the completionHandler when finished
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ request: @autoclosure () -> URLRequest,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: @escaping (Results) -> Void) {
            self.init(request(), usingSession: session())
            
            //self.completionHandler = completionHandler
            self.eventDelegate.completionHandler = { location, response, error in
                self.results = Results(request: self.originalRequest!,
                                       response: response,
                                       error: error,
                                       location: location)
                
                /// was async
                self.callSyncEventHandler { completionHandler(self.results) }
            }
        }
        
        /// Create a new WebRequest using the provided url and session. and call the completionHandler when finished
        ///
        /// - Parameters:
        ///   - url: The url to request
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ url: @autoclosure () -> URL,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: @escaping (Results) -> Void) {
            self.init(URLRequest(url: url()),
                      usingSession: session(),
                      completionHandler: completionHandler)
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
        
        public override func cancel() {
            self.task.cancel()
            super.cancel()
        }
    }
}
