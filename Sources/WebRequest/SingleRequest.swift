//
//  SingleWebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2018-06-06.
//

import Foundation

public extension WebRequest {
    /*
     Allows for a single web request
    */
    public class SingleRequest: WebRequest {
        
        private var task: URLSessionDataTask
        
        // Results from the request
        public private(set) var results: WebRequest.Results
        private var completionHandler: ((WebRequest.Results) -> Void)? = nil
        
        public override var state: WebRequest.State { return WebRequest.State(rawValue: self.task.state.rawValue)! }
        
        // The URL request object currently being handled by the request.
        public var currentRequest: URLRequest? { return self.task.currentRequest }
        // The original request object passed when the request was created.
        public var originalRequest: URLRequest? { return self.task.originalRequest }
        // The server’s response to the currently active request.
        public var response: URLResponse? { return self.task.response }
        
        // An app-provided description of the current request.
        public var webDescription: String? {
            get { return self.task.taskDescription }
            set { self.task.taskDescription = newValue }
        }
        // An identifier uniquely identifies the task within a given session.
        public var taskIdentifier: Int { return self.task.taskIdentifier }
        
        public override var error: Swift.Error? { return self.task.error }
        
        // The relative priority at which you’d like a host to handle the task, specified as a floating point value between 0.0 (lowest priority) and 1.0 (highest priority).
        public var priority: Float {
            get { return self.task.priority }
            set { self.task.priority = newValue }
        }
        
        // A representation of the overall request progress
        @available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
        public override var progress: Progress { return self.task.progress }
        
         // Create a new WebRequest using the provided url and session.
        public init(_ request: URLRequest, usingSession session: URLSession) {
            self.task = URLSessionDataTask()
            self.results = Results(request: request)
            super.init()
            self.task = session.dataTask(with: request) { data, response, error in
                
                self.results = Results(request: request, response: response, error: error, data: data)

                
                self.triggerStateChange(.completed)
                
                if let handler = self.completionHandler {
                    DispatchQueue.global().async { handler(self.results) }
                }
                
            }
        }
        
         // Create a new WebRequest using the provided url and session
        public convenience init(_ url: URL, usingSession session: URLSession) {
            self.init(URLRequest(url: url), usingSession: session)
        }
        
         // Create a new WebRequest using the provided requset and session. and call the completionHandler when finished
        public convenience init(_ request: URLRequest, usingSession session: URLSession, completionHandler: @escaping (WebRequest.Results) -> Void) {
            self.init(request, usingSession: session)
            self.completionHandler = completionHandler
        }
        
        // Create a new WebRequest using the provided url and session. and call the completionHandler when finished
        public convenience init(_ url: URL, usingSession session: URLSession, completionHandler: @escaping (WebRequest.Results) -> Void) {
            self.init(URLRequest(url: url), usingSession: session, completionHandler: completionHandler)
        }
        
        // Resumes the request, if it is suspended.
        public override func resume() {
            super.resume()
            self.task.resume()
        }
        
        // Temporarily suspends a request.
        public override func suspend() {
            super.suspend()
            self.task.suspend()
        }
        
        // Cancels the request
        public override func cancel() {
            super.cancel()
            self.task.cancel()
        }
    }
}
