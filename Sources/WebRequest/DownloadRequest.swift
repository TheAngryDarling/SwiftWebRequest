//
//  DownloadRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-26.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
#endif

public extension WebRequest {
    /// Allows for a single download web request
    class DownloadRequest: TaskedWebRequest<URL> {
        
        private class URLSessionDownloadTaskEventHandler: URLSessionTaskEventHandlerWithCompletionHandler<URL>,
                                                          URLSessionDownloadDelegate {
            public private(set) var didFinishDownloadingToHandler: [String: (URLSession, URLSessionTask, URL) -> Void] = [:]
            
            /// Add event handler
            @discardableResult
            public func addDidFinishDownloadingToHandler(withId uid: String,
                                                         _ handler: @escaping (URLSession, URLSessionTask, URL) -> Void) -> String {
                precondition(!self.didFinishDownloadingToHandler.keys.contains(uid), "Id already in use")
                self.didFinishDownloadingToHandler[uid] = handler
                self.hasEventHandlers = true
                return uid
            }
            /// Add event handler
            @discardableResult
            public func addDidFinishDownloadingToHandler(_ handler: @escaping (URLSession, URLSessionTask, URL) -> Void) -> String {
                return self.addDidFinishDownloadingToHandler(withId: UUID().uuidString, handler)
            }
            /// Remove event handler with the given Id
            public func removeDidFinishDownloadingToHandler(withId id: String) {
                self.didFinishDownloadingToHandler.removeValue(forKey: id)
            }
            
            func urlSession(_ session: URLSession,
                            task: URLSessionTask,
                            didFinishDownloadingTo location: URL) {
                // Only accept events for the given request
                guard self.isWorkingTask(task) else { return }
                
                self.results = location
                for (_, handler) in self.didFinishDownloadingToHandler {
                    if let q = self.eventHandlerQueue {
                        q.sync {
                            handler(session, task, location)
                        }
                    } else {
                        handler(session, task, location)
                    }
                }
            }
            
            func urlSession(_ session: URLSession,
                            downloadTask: URLSessionDownloadTask,
                            didFinishDownloadingTo location: URL) {
                // Only accept events for the given request
                guard self.isWorkingTask(downloadTask) else { return }
                
                self.urlSession(session,
                                task: downloadTask,
                                didFinishDownloadingTo: location)
            }
            
            public private(set) var didResumeAtOffsetHandler: [String: (URLSession, URLSessionTask, Int64, Int64) -> Void] = [:]
            
            /// Add event handler
            @discardableResult
            public func addDidResumeAtOffsetHandler(withId uid: String,
                                                    _ handler: @escaping (URLSession, URLSessionTask, Int64, Int64) -> Void) -> String {
                precondition(!self.didResumeAtOffsetHandler.keys.contains(uid), "Id already in use")
                self.didResumeAtOffsetHandler[uid] = handler
                self.hasEventHandlers = true
                return uid
            }
            
            /// Add event handler
            @discardableResult
            public func addDidResumeAtOffsetHandler(_ handler: @escaping (URLSession, URLSessionTask, Int64, Int64) -> Void) -> String {
                return self.addDidResumeAtOffsetHandler(withId: UUID().uuidString, handler)
            }
            /// Remove event handler with the given Id
            public func removeDidResumeAtOffsetHandler(withId id: String) {
                self.didResumeAtOffsetHandler.removeValue(forKey: id)
            }
            
            func urlSession(_ session: URLSession,
                            downloadTask: URLSessionDownloadTask,
                            didResumeAtOffset fileOffset: Int64,
                            expectedTotalBytes: Int64) {
                // Only accept events for the given request
                guard self.isWorkingTask(downloadTask) else { return }
                
                for (_, handler) in self.didResumeAtOffsetHandler {
                    if let q = self.eventHandlerQueue {
                        q.sync {
                            handler(session, downloadTask, fileOffset, expectedTotalBytes)
                        }
                    } else {
                        handler(session, downloadTask, fileOffset, expectedTotalBytes)
                    }
                }
            }
            
            public private(set) var didWriteDataHandler: [String: (URLSession, URLSessionTask, Int64, Int64, Int64) -> Void] = [:]
            
            /// Add event handler
            @discardableResult
            public func addDidWriteDataHandler(withId uid: String,
                                               _ handler: @escaping (URLSession, URLSessionTask, Int64, Int64, Int64) -> Void) -> String {
                precondition(!self.didWriteDataHandler.keys.contains(uid), "Id already in use")
                self.didWriteDataHandler[uid] = handler
                self.hasEventHandlers = true
                return uid
            }
            /// Add event handler
            @discardableResult
            public func addDidWriteDataHandler(_ handler: @escaping (URLSession, URLSessionTask, Int64, Int64, Int64) -> Void) -> String {
                return self.addDidWriteDataHandler(withId: UUID().uuidString, handler)
            }
            /// Remove event handler with the given Id
            public func removeWriteDataHandler(withId id: String) {
                self.didWriteDataHandler.removeValue(forKey: id)
            }
            
            func urlSession(_ session: URLSession,
                            task: URLSessionTask,
                            didWriteData bytesWritten: Int64,
                            totalBytesWritten: Int64,
                            totalBytesExpectedToWrite: Int64) {
                
                // Only accept events for the given request
                guard self.isWorkingTask(task) else { return }
                
                for (_, handler) in self.didWriteDataHandler {
                    if let q = self.eventHandlerQueue {
                        q.async {
                            handler(session,
                                    task,
                                    bytesWritten,
                                    totalBytesWritten,
                                    totalBytesExpectedToWrite)
                        }
                    } else {
                        handler(session,
                                task,
                                bytesWritten,
                                totalBytesWritten,
                                totalBytesExpectedToWrite)
                    }
                }
            }
            
            
            func urlSession(_ session: URLSession,
                            downloadTask: URLSessionDownloadTask,
                            didWriteData bytesWritten: Int64,
                            totalBytesWritten: Int64,
                            totalBytesExpectedToWrite: Int64) {
                
                // Only accept events for the given request
                guard self.isWorkingTask(downloadTask) else { return }
                
                urlSession(session,
                           task: downloadTask,
                           didWriteData: bytesWritten,
                           totalBytesWritten: totalBytesWritten,
                           totalBytesExpectedToWrite: totalBytesExpectedToWrite)
            }
            
            override func removeHandlers(withId uid: String) {
                self.didFinishDownloadingToHandler.removeValue(forKey: uid)
                self.didResumeAtOffsetHandler.removeValue(forKey: uid)
                self.didWriteDataHandler.removeValue(forKey: uid)
                super.removeHandlers(withId: uid)
            }
        }
        
        private class URLSessionDataTaskEventHandler: URLSessionDownloadTaskEventHandler,
                                                      URLSessionDataDelegate {
            
            
            /// Unique temp file
            let uniqueTempFileURL = URL(fileURLWithPath: NSTemporaryDirectory(),
                                        isDirectory: true)
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("tmp")
            
            var totalBytesWritten: Int64 = 0
            
            override func urlSession(_ session: URLSession,
                                     didBecomeInvalidWithError error: Error?) {
                super.urlSession(session, didBecomeInvalidWithError: error)
                
                //print("Removing download file didBecomeInvalidWithError")
                try? FileManager.default.removeItem(at: self.uniqueTempFileURL)
            }
            
            override func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
                super.urlSessionDidFinishEvents(forBackgroundURLSession: session)
                
                //print("Removing download file forBackgroundURLSession")
                try? FileManager.default.removeItem(at: self.uniqueTempFileURL)
            }
            
            
            override func urlSession(_ session: URLSession,
                                     task: URLSessionTask,
                                     didCompleteWithError error: Error?) {
                
                // Only accept events for the given request
                guard self.isWorkingTask(task) else { return }
                
                if error == nil &&
                    FileManager.default.fileExists(atPath: self.uniqueTempFileURL.path) {
                    super.urlSession(session,
                                     task: task,
                                     didFinishDownloadingTo: self.uniqueTempFileURL)
                }
                
                super.urlSession(session,
                                 task: task,
                                 didCompleteWithError: error)
                
                //print("Removing download file didCompleteWithError")
                try? FileManager.default.removeItem(at: self.uniqueTempFileURL)

            }
            
            func urlSession(_ session: URLSession,
                            dataTask: URLSessionDataTask,
                            didReceive data: Data) {
                
                // Only accept events for the given request
                guard self.isWorkingTask(dataTask) else { return }
                
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
                
                var expectedBytesWritten: Int64 = NSURLSessionTransferSizeUnknown
                if let response = dataTask.response,
                   let httpResponse = response as? HTTPURLResponse,
                   let anyContentLength = httpResponse.allHeaderFields["Content-Length"],
                   let strContentLength = anyContentLength as? String,
                   let intConentLength = Int64(strContentLength) {
                    expectedBytesWritten = intConentLength
                }
                
                
                self.urlSession(session,
                                task: dataTask,
                                didWriteData: bitesWriten,
                                totalBytesWritten: self.totalBytesWritten,
                                totalBytesExpectedToWrite: expectedBytesWritten)
                
            }
            
        }
        
        public typealias Results = TaskedWebRequestResults<URL>
        
        private var downloadEventDelegate: URLSessionDownloadTaskEventHandler {
            return self.eventDelegate as! URLSessionDownloadTaskEventHandler
        }
        
        
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - request: The request to execute
        ///   - name: Custom Name identifing this request
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public init(_ request: @autoclosure () -> URLRequest,
                    name: String? = nil,
                    usingSession session: @autoclosure () -> URLSession,
                    completionHandler: ((Results) -> Void)? = nil) {
            #if swift(>=5.3) || _runtime(_ObjC)
            let delegate = URLSessionDownloadTaskEventHandler()
            #else
            let delegate = URLSessionDataTaskEventHandler()
            #endif
            
            let session = URLSession(copy: session(),
                                     delegate: delegate)
            
            #if swift(>=5.3) || _runtime(_ObjC)
            let task = session.downloadTask(with: request())
            #else
            let task = session.dataTask(with: request())
            #endif
            
            super.init(task,
                       name: name,
                       session: session,
                       eventDelegate: delegate,
                       //originalRequest: req,
                       completionHandler: completionHandler)
            
            
        }
        
        /// Create a new WebRequest using the provided url and session
        ///
        /// - Parameters:
        ///   - url: The url to request
        ///   - name: Custom Name identifing this request   
        ///   - session: The URL Session to copy the configuration/queue from
        ///   - completionHandler: The call back when done executing
        public convenience init(_ url: @autoclosure () -> URL,
                                name: String? = nil,
                                usingSession session: @autoclosure () -> URLSession,
                                completionHandler: ((Results) -> Void)? = nil) {
            self.init(URLRequest(url: url()),
                      name: name,
                      usingSession: session(),
                      completionHandler: completionHandler)
        }
        
        
        
        /// Add event handler
        @discardableResult
        public func addDidFinishDownloadingToHandler(withId uid: String,
                                                     _ handler: @escaping (URLSession, DownloadRequest, URL) -> Void) -> String {
            return self.downloadEventDelegate.addDidFinishDownloadingToHandler(withId: uid) { [weak self] session, _, url in
                guard let currentSelf = self else { return }
                handler(session, currentSelf, url)
            }
        }
        /// Add event handler
        @discardableResult
        public func addDidFinishDownloadingToHandler(_ handler: @escaping (URLSession, DownloadRequest, URL) -> Void) -> String {
            return self.downloadEventDelegate.addDidFinishDownloadingToHandler { [weak self] session, _, url in
                guard let currentSelf = self else { return }
                handler(session, currentSelf, url)
            }
        }
        /// Remove event handler with the given Id
        public func removeDidFinishDownloadingToHandler(withId id: String) {
            self.downloadEventDelegate.removeDidFinishDownloadingToHandler(withId: id)
        }
        
        /// Add event handler
        @discardableResult
        public func addDidResumeAtOffsetHandler(withId uid: String,
                                                _ handler: @escaping (URLSession, DownloadRequest, Int64, Int64) -> Void) -> String {
            return self.downloadEventDelegate.addDidResumeAtOffsetHandler(withId: uid) { [weak self] session, _, a, b in
                guard let currentSelf = self else { return }
                handler(session, currentSelf, a, b)
            }
        }
        
        /// Add event handler
        @discardableResult
        public func addDidResumeAtOffsetHandler(_ handler: @escaping (URLSession, DownloadRequest, Int64, Int64) -> Void) -> String {
            return self.downloadEventDelegate.addDidResumeAtOffsetHandler { [weak self] session, _, a, b in
                guard let currentSelf = self else { return }
                handler(session, currentSelf, a, b)
            }
        }
        /// Remove event handler with the given Id
        public func removeDidResumeAtOffsetHandler(withId id: String) {
            self.downloadEventDelegate.removeDidResumeAtOffsetHandler(withId: id)
        }
        
        /// Add event handler
        @discardableResult
        public func addDidWriteDataHandler(withId uid: String,
                                           _ handler: @escaping (URLSession, DownloadRequest, Int64, Int64, Int64) -> Void) -> String {
            return self.downloadEventDelegate.addDidWriteDataHandler(withId: uid) { [weak self] session, _, a, b, c in
                guard let currentSelf = self else { return }
                handler(session, currentSelf, a, b, c)
            }
        }
        /// Add event handler
        @discardableResult
        public func addDidWriteDataHandler(_ handler: @escaping (URLSession, DownloadRequest, Int64, Int64, Int64) -> Void) -> String {
            return self.downloadEventDelegate.addDidWriteDataHandler { [weak self] session, _, a, b, c in
                guard let currentSelf = self else { return }
                handler(session, currentSelf, a, b, c)
            }
        }
        
        /// Remove event handler with the given Id
        public func removeWriteDataHandler(withId id: String) {
            self.downloadEventDelegate.removeWriteDataHandler(withId: id)
        }
        
    }
}
