//
//  TaskedWebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-02-03.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif

fileprivate func asNSError(_ error: Error?) -> NSError? {
    guard let e = error else { return nil }
    #if _runtime(_ObjC) || swift(>=4.1.4)
    return (e as NSError)
    #else
    return e as? NSError
    #endif
}

public protocol TaskedWebRequestResultsContainer {
    /// Empty any locally loaded WebRequest Data
    mutating func emptyLocallyLoadedData()
}

public typealias TaskedWebRequestCompletionHandlerResults = TaskedWebRequestResultsContainer

public extension WebRequest {
    
    internal class URLSessionTaskEventHandler: NSObject,
                                               URLSessionTaskDelegate {
        
        
        public internal(set) var hasEventHandlers: Bool = false
        
        deinit {
            self.removeAllHandlers()
        }
        
        public private(set) var didSendBodyDataHandler: [String: (URLSession, URLSessionTask, Int64, Int64, Int64) -> Void] = [:]
        
        /// Add event handler
        @discardableResult
        public func addDidSendBodyDataHandler(withId uid: String,
                                              _ handler: @escaping (URLSession,
                                                                    URLSessionTask,
                                                                    Int64,
                                                                    Int64,
                                                                    Int64) -> Void) -> String {
            precondition(!self.didSendBodyDataHandler.keys.contains(uid), "Id already in use")
            self.didSendBodyDataHandler[uid] = handler
            self.hasEventHandlers = true
            return uid
        }
        
        /// Add event handler
        @discardableResult
        public func addDidSendBodyDataHandler(_ handler: @escaping (URLSession,
                                                                    URLSessionTask,
                                                                    Int64,
                                                                    Int64,
                                                                    Int64) -> Void) -> String {
            return self.addDidSendBodyDataHandler(withId: UUID().uuidString, handler)
        }
        /// Remove event handler with the given Id
        public func removeDidSendBodyDataHandler(withId uid: String) {
            self.didSendBodyDataHandler.removeValue(forKey: uid)
        }
        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        didSendBodyData bytesSent: Int64,
                        totalBytesSent: Int64,
                        totalBytesExpectedToSend: Int64) {
            for (_, handler) in self.didSendBodyDataHandler {
                handler(session,
                        task,
                        bytesSent,
                        totalBytesSent,
                        totalBytesExpectedToSend)
            }
        }

        
        public private(set) var didCompleteWithErrorHandler: [String: (URLSession, URLSessionTask, Error?) -> Void] = [:]
        /// Add event handler
        @discardableResult
        public func addDidCompleteWithErrorHandler(withId uid: String,
                                                   _ handler: @escaping (URLSession,
                                                                         URLSessionTask,
                                                                         Error?) -> Void) -> String {
            precondition(!self.didCompleteWithErrorHandler.keys.contains(uid), "Id already in use")
            self.didCompleteWithErrorHandler[uid] = handler
            self.hasEventHandlers = true
            return uid
        }
        /// Add event handler
        @discardableResult
        public func addDidCompleteWithErrorHandler(_ handler: @escaping (URLSession,
                                                                         URLSessionTask,
                                                                         Error?) -> Void) -> String {
            return self.addDidCompleteWithErrorHandler(withId: UUID().uuidString, handler)
        }
        /// Remove event handler with the given Id
        public func removeDidCompleteWithErrorHandler(withId uid: String) {
            self.didCompleteWithErrorHandler.removeValue(forKey: uid)
        }
        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        didCompleteWithError error: Error?) {
            for (_, handler) in self.didCompleteWithErrorHandler {
                handler(session, task, error)
            }
        }
        
        
        public private(set) var didBecomeInvalidWithErrorHandler: [String: (URLSession, Error?) -> Void] = [:]
        
        /// Add event handler
        @discardableResult
        public func addBecomeInvalidWithErrorHandler(withId uid: String,
                                                     _ handler: @escaping (URLSession,
                                                                           Error?) -> Void) -> String {
            precondition(!self.didBecomeInvalidWithErrorHandler.keys.contains(uid), "Id already in use")
            self.didBecomeInvalidWithErrorHandler[uid] = handler
            self.hasEventHandlers = true
            return uid
        }
        /// Add event handler
        @discardableResult
        public func addBecomeInvalidWithErrorHandler(_ handler: @escaping (URLSession,
                                                                           Error?) -> Void) -> String {
            return self.addBecomeInvalidWithErrorHandler(withId: UUID().uuidString, handler)
        }
        /// Remove event handler with the given Id
        public func removeBecomeInvalidWithErrorHandler(withId uid: String) {
            self.didBecomeInvalidWithErrorHandler.removeValue(forKey: uid)
        }
        func urlSession(_ session: URLSession,
                        didBecomeInvalidWithError error: Error?) {
            for (_, handler) in self.didBecomeInvalidWithErrorHandler {
                handler(session, error)
            }
        }
        
        public private(set) var sessionDidFinishEventsForBackgroundHandler: [String: (URLSession) -> Void] = [:]
        
        /// Add event handler
        @discardableResult
        public func addSessionDidFinishEventsForBackgroundHandler(withId uid: String,
                                                                  _ handler: @escaping (URLSession) -> Void) -> String {
            precondition(!self.sessionDidFinishEventsForBackgroundHandler.keys.contains(uid), "Id already in use")
            self.sessionDidFinishEventsForBackgroundHandler[uid] = handler
            self.hasEventHandlers = true
            return uid
        }
        /// Add event handler
        @discardableResult
        public func addSessionDidFinishEventsForBackgroundHandler(_ handler: @escaping (URLSession) -> Void) -> String {
            return self.addSessionDidFinishEventsForBackgroundHandler(withId: UUID().uuidString, handler)
        }
        /// Remove event handler with the given Id
        public func removeSessionDidFinishEventsForBackgroundHandler(withId uid: String) {
            self.sessionDidFinishEventsForBackgroundHandler.removeValue(forKey: uid)
        }
        
        func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
            for (_, handler) in self.sessionDidFinishEventsForBackgroundHandler {
                handler(session)
            }
        }
        
        public func removeHandlers(withId uid: String) {
            self.didSendBodyDataHandler.removeValue(forKey: uid)
            self.didCompleteWithErrorHandler.removeValue(forKey: uid)
            self.didBecomeInvalidWithErrorHandler.removeValue(forKey: uid)
            self.sessionDidFinishEventsForBackgroundHandler.removeValue(forKey: uid)
        }
        
        public func removeAllHandlers() {
            self.didSendBodyDataHandler.removeAll()
            self.didCompleteWithErrorHandler.removeAll()
            self.didBecomeInvalidWithErrorHandler.removeAll()
            self.sessionDidFinishEventsForBackgroundHandler.removeAll()
        }
    }
    
    
    internal class URLSessionTaskEventHandlerWithCompletionHandler<CompletionResults>: URLSessionTaskEventHandler where CompletionResults: TaskedWebRequestCompletionHandlerResults {
        internal var taskResults: [Int: CompletionResults] = [:]
        //public var results: CompletionResults?
        
        deinit {
            for k in self.taskResults.keys {
                self.taskResults[k]!.emptyLocallyLoadedData()
            }
            self.taskResults.removeAll(keepingCapacity: false)
        }
        override func urlSession(_ session: URLSession,
                                 task: URLSessionTask,
                                 didCompleteWithError error: Error?) {
            
            for (_, handler) in self.completionHandler {
                WebRequest.autoreleasepool {
                    handler(self.taskResults[task.taskIdentifier], task.response, error)
                }
            }
            super.urlSession(session, task: task, didCompleteWithError: error)
            self.taskResults[task.taskIdentifier]?.emptyLocallyLoadedData()
            self.taskResults.removeValue(forKey: task.taskIdentifier)
        }
        
        
        public private(set) var completionHandler: [String: (CompletionResults?, URLResponse?, Error?) -> Void] = [:]
        
        /// Add event handler
        @discardableResult
        public func addCompletionHandler(withId uid: String,
                                         _ handler: @escaping (CompletionResults?, URLResponse?, Error?) -> Void) -> String {
            precondition(!self.completionHandler.keys.contains(uid), "Id already in use")
            self.completionHandler[uid] = handler
            self.hasEventHandlers = true
            return uid
        }
        /// Add event handler
        @discardableResult
        public func addCompletionHandler(_ handler: @escaping (CompletionResults?, URLResponse?, Error?) -> Void) -> String {
            return self.addCompletionHandler(withId: UUID().uuidString, handler)
        }
        /// Remove event handler with the given Id
        public func removeCompletionHandler(withId id: String) {
            self.completionHandler.removeValue(forKey: id)
        }
        
        public override func removeHandlers(withId uid: String) {
            self.completionHandler.removeValue(forKey: uid)
            super.removeHandlers(withId: uid)
        }
        
        public override func removeAllHandlers() {
            self.completionHandler.removeAll()
            super.removeAllHandlers()
        }
    }
    
    
    /// Results container for request response
    struct TaskedWebRequestResults<Results> where Results: TaskedWebRequestResultsContainer {
        /// Represents the generate type used as the results of the request operation (like Data, URL)
        public typealias ResultsType = Results
        
        public let request: URLRequest
        public let response: URLResponse?
        public let error: Error?
        public internal(set) var results: Results?
        
        /// The original url of the request
        public var originalURL: URL? { return request.url }
        /// The url from the response.   This could differ from the originalURL if there were redirects
        public var currentURL: URL? {
            if let r = response?.url { return r }
            else { return originalURL }
        }
        
        internal var hasResponse: Bool {
            return (self.response != nil || self.error != nil || self.results != nil)
        }
        
        public init(request: URLRequest,
                    response: URLResponse? = nil,
                    error: Error? = nil,
                    results: Results? = nil) {
            self.request = request
            self.response = response
            self.error = error
            self.results = results
        }
        
        public mutating func clearResults() {
            self.results?.emptyLocallyLoadedData()
            self.results = nil
        }
        
        internal static func generateCanceledResults(for request: URLRequest) -> TaskedWebRequestResults {
            return .init(request: request,
                         response: nil,
                         error: WebRequest.createCancelationError(forURL: request.url!),
                         results: nil)
        }
    }
    
    class TaskedWebRequest<CompletionResults>: WebRequest where CompletionResults: TaskedWebRequestResultsContainer {
        
        /// TypeAlias defining the Results of the request(TaskedWebRequestResults) to a specific result type
        public typealias Results = TaskedWebRequestResults<CompletionResults>
        
        private var task: URLSessionTask! = nil
        private weak var session: URLSession?
        
        /// Results from the request
        internal var _results: Results? = nil
        public var results: Results {
            return _results ?? Results(request: self.originalRequest!)
        }
        
        /// The last state set from the resume/suspend/cancel methods
        private var _previousState: WebRequest.State = .suspended
        
        public override var state: WebRequest.State {
            //Some times completion handler gets called even though task state says its still running on linux
            guard self.results.hasResponse else {
                return WebRequest.State(rawValue: self.task.state.rawValue)!
            }
            
            #if _runtime(_ObjC) || swift(>=4.1.4)
             if let e = self.results.error,
                (e as NSError).code == NSURLErrorCancelled {
                return WebRequest.State.canceling
             } else {
                return WebRequest.State.completed
             }
            #else
             if let e = self.results.error,
                let nsE = e as? NSError,
                nsE.code == NSURLErrorCancelled {
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
        public var originalRequest: URLRequest? { return self.task.originalRequest }
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
        
        internal let eventDelegate: URLSessionTaskEventHandlerWithCompletionHandler<CompletionResults>
        
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
        
        /// Create a new WebRequest using the provided url and session.
        ///
        /// - Parameters:
        ///   - task: The task executing the request
        ///   - name: Custom Name identifing this request
        ///   - session: The session used to create the task that should be invalidated
        ///   - eventDelegate: The delegate used to monitor the task events
        ///   - originalRequest: The original request of the task
        ///   - completionHandler: The call back when done executing
        internal init(_ task: URLSessionTask,
                      name: String? = nil,
                      session: URLSession?,
                      eventDelegate: URLSessionTaskEventHandlerWithCompletionHandler<CompletionResults>,
                      completionHandler: ((Results) -> Void)? = nil) {
            //print("Creating Tasked Request")
            self.task = task
            self.session = session
            self.eventDelegate = eventDelegate
            super.init(name: name)
            self.eventDelegate.addCompletionHandler(withId: "self") { [weak self] results, response, error in
                guard self != nil else { return }
                let results = TaskedWebRequestResults<CompletionResults>(request: self!.originalRequest!,
                                                                   response: response,
                                                                   error: error,
                                                                   results: results)
                
                self!._results = results
                self!.triggerStateChange(from: self!._previousState, to: self!.state)
                if let ch = completionHandler {
                    self!.callSyncEventHandler { ch(results) }
                }
            }
            
        }
        
        deinit {
            self._results?.clearResults()
            self._results = nil
            self.eventDelegate.removeAllHandlers()
            self.session?.finishTasksAndInvalidate()
        }
        
        /// Add event handler
        @discardableResult
        public func addDidSendBodyDataHandler(withId uid: String,
                                              _ handler: @escaping (URLSession,
                                                                    TaskedWebRequest<CompletionResults>,
                                                                    Int64,
                                                                    Int64,
                                                                    Int64) -> Void) -> String {
            return self.eventDelegate.addDidSendBodyDataHandler(withId: uid) { [weak self] session, _, a, b, c in
                guard self != nil else { return }
                handler(session, self!, a, b, c)
            }
        }
        /// Add event handler
        @discardableResult
        public func addDidSendBodyDataHandler(_ handler: @escaping (URLSession,
                                                                    TaskedWebRequest<CompletionResults>,
                                                                    Int64,
                                                                    Int64,
                                                                    Int64) -> Void) -> String {
            return self.eventDelegate.addDidSendBodyDataHandler { [weak self] session, _, a, b, c in
                guard self != nil else { return }
                handler(session, self!, a, b, c)
            }
        }
        /// Remove event handler with the given Id
        public func removeDidSendBodyDataHandler(withId uid: String) {
            self.eventDelegate.removeDidSendBodyDataHandler(withId: uid)
        }
        
        /// Add event handler
        @discardableResult
        public func addDidCompleteWithErrorHandler(withId uid: String,
                                                   _ handler: @escaping (URLSession,
                                                                         TaskedWebRequest<CompletionResults>,
                                                                         Error?) -> Void) -> String {
            return self.eventDelegate.addDidCompleteWithErrorHandler(withId: uid) { [weak self] session, _, error in
                guard self != nil else { return }
                handler(session, self!, error)
            }
        }
        
        /// Add event handler
        @discardableResult
        public func addDidCompleteWithErrorHandler(_ handler: @escaping (URLSession,
                                                                         TaskedWebRequest<CompletionResults>,
                                                                         Error?) -> Void) -> String {
            return self.eventDelegate.addDidCompleteWithErrorHandler { [weak self] session, _, error in
                guard self != nil else { return }
                handler(session, self!, error)
            }
        }
        /// Remove event handler with the given Id
        public func removeDidCompleteWithErrorHandler(withId uid: String) {
            self.eventDelegate.removeDidCompleteWithErrorHandler(withId: uid)
        }
        /// Add event handler
        @discardableResult
        public func addBecomeInvalidWithErrorHandler(withId uid: String,
                                                     _ handler: @escaping (URLSession,
                                                                           Error?) -> Void) -> String {
            return self.eventDelegate.addBecomeInvalidWithErrorHandler(withId: uid, handler)
        }
        /// Add event handler
        @discardableResult
        public func addBecomeInvalidWithErrorHandler(_ handler: @escaping (URLSession,
                                                                           Error?) -> Void) -> String {
            return self.eventDelegate.addBecomeInvalidWithErrorHandler(handler)
        }
        /// Remove event handler with the given Id
        public func removeBecomeInvalidWithErrorHandler(withId uid: String) {
            return self.eventDelegate.removeBecomeInvalidWithErrorHandler(withId: uid)
        }
        
        /// Add event handler
        @discardableResult
        public func addSessionDidFinishEventsForBackgroundHandler(withId uid: String,
                                                                  _ handler: @escaping (URLSession) -> Void) -> String {
            return self.eventDelegate.addSessionDidFinishEventsForBackgroundHandler(withId: uid, handler)
        }
        /// Add event handler
        @discardableResult
        public func addSessionDidFinishEventsForBackgroundHandler(_ handler: @escaping (URLSession) -> Void) -> String {
            return self.eventDelegate.addSessionDidFinishEventsForBackgroundHandler(handler)
        }
        /// Remove event handler with the given Id
        public func removeSessionDidFinishEventsForBackgroundHandler(withId uid: String) {
            self.eventDelegate.removeSessionDidFinishEventsForBackgroundHandler(withId: uid)
        }
        
        /// Remove all handlers with the given Id
        public func removeHandlers(withId uid: String) {
            self.eventDelegate.removeHandlers(withId: uid)
        }
        
        public override func resume()  {
            guard self.state == .suspended else { return }
            self._previousState = .running
            self.triggerStateChange(from: .suspended, to: .running)
            
            self.task.resume()
        }
        
        public override func suspend() {
            guard self.state == .running else { return }
            self._previousState = .suspended
            self.task.suspend()
            self.triggerStateChange(from: .running, to: .suspended)
        }
        
        public override func cancel() {
            let currentState = self.state
            guard currentState == .running || currentState == .suspended else { return }
            
            self._previousState = .canceling
            
            //Setup results for cancelled requests
            if !self.results.hasResponse {
                self._results?.clearResults()
                self._results = .generateCanceledResults(for: self.originalRequest!)
            }
            
            self.triggerStateChange(from: currentState, to: .canceling)
            
            self.task.cancel()
            
        }
        
        
    }
}

#if swift(>=5.5)
public extension WebRequest.TaskedWebRequest {
    @available(macOS 10.15.0, *)
    func safeExecute() async -> Results {
        
        self.resume()
        self.waitUntilComplete()
        
        return self.results
    }
    
    @available(macOS 10.15.0, *)
    func execute() async throws -> (Results.ResultsType?, URLRequest, URLResponse) {
        
        self.resume()
        self.waitUntilComplete()
        
        let r = self.results
        if let e = r.error {
            throw e
        } else {
            return (r.results, r.request, r.response!)
        }
    }
}
#endif

public extension WebRequest.TaskedWebRequestResults where Results == URL {
    /// Same as results
    var location: URL? { return self.results }
    
    /*convenience*/ init(request: URLRequest,
                     response: URLResponse? = nil,
                     error: Error? = nil,
                     location: URL?) {
        
        self.init(request: request,
                  response: response,
                  error: error,
                  results: location)
    }
}

public extension WebRequest.TaskedWebRequestResults where Results == Data {
    /// Same as results
    var data: Data? { return self.results }
    
    /*convenience*/ init(request: URLRequest,
                            response: URLResponse? = nil,
                            error: Error? = nil,
                            data: Data?) {
        
        self.init(request: request,
                  response: response,
                  error: error,
                  results: data)
    }
    /// Allows for clearing of the reponse data.
    /// This can be handy when working with GroupRequests with a lot of data.
    /// That way you can process each request as it comes in and clear the data so its not sitting in memeory until all requests are finished
    internal mutating func emptyData() {
        self.clearResults()
    }
    
    /// Trys to convert the resposne data to a string using the response.textEncodingName if provided.
    /// If not it will use the defaultEncoding that is passed into the method
    func responseString(defaultEncoding encoding: String.Encoding = .utf8) -> String? {
        guard let response = self.response else { return nil }
        guard let data = self.data else { return nil }
        var responseEncoding: String.Encoding? = nil
        if let textEncodingName = response.textEncodingName, !textEncodingName.isEmpty {
            responseEncoding = WebRequest.StringEncoding.encodingNameToStringEncoding(textEncodingName)
        }
        
        let encoding = responseEncoding ?? encoding
        //let rtn = String(data: data, encoding: encoding)
        //return rtn
        return String(data: data, encoding: encoding)
    }
}

extension WebRequest {
    
    /// Used for response.textEncodingName to String.Encoding
    fileprivate struct StringEncoding {
        #if _runtime(_ObjC)
        public static func encodingNameToStringEncoding(_ name: String) -> String.Encoding? {
            let cfe = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            if cfe == kCFStringEncodingInvalidId { return nil }
            let se = CFStringConvertEncodingToNSStringEncoding(cfe)
            return String.Encoding(rawValue: se)
        }
        #else
        public static let NAMED_ENCODING_MAP: [String: UInt] = [
            "437": 2147484672,
            "850": 2147484688,
            "851": 2147484689,
            "852": 2147484690,
            "855": 2147484691,
            "857": 2147484692,
            "860": 2147484693,
            "861": 2147484694,
            "862": 2147484695,
            "863": 2147484696,
            "865": 2147484698,
            "866": 2147484699,
            "869": 2147484700,
            "Adobe-Symbol-Encoding": 6,
            "ANSI_X3.4-1968": 1,
            "ANSI_X3.4-1986": 1,
            "arabic": 2147483652,
            "ASCII": 1,
            "ASMO-708": 2147484166,
            "Big5": 2147486211,
            "Big5-HKSCS": 2147486214,
            "chinese": 2147486000,
            "cp-gr": 2147484700,
            "cp-is": 2147484694,
            "cp037": 2147486722,
            "cp367": 1,
            "cp437": 2147484672,
            "cp775": 2147484678,
            "CP819": 5,
            "cp850": 2147484688,
            "cp851": 2147484689,
            "cp852": 2147484690,
            "cp855": 2147484691,
            "cp857": 2147484692,
            "cp860": 2147484693,
            "cp861": 2147484694,
            "cp862": 2147484695,
            "cp863": 2147484696,
            "cp864": 2147484697,
            "cp865": 2147484698,
            "cp866": 2147484699,
            "cp869": 2147484700,
            "CP936": 2147484705,
            "csASCII": 1,
            "csBig5": 2147484707,
            "csEUCKR": 2147486016,
            "csEUCPkdFmtJapanese": 3,
            "csGB2312": 2147486000,
            "csHalfWidthKatakana": 2147485216,
            "csIBM037": 2147486722,
            "csIBM855": 2147484691,
            "csIBM857": 2147484692,
            "csIBM860": 2147484693,
            "csIBM861": 2147484694,
            "csIBM863": 2147484696,
            "csIBM864": 2147484697,
            "csIBM865": 2147484698,
            "csIBM866": 2147484699,
            "csIBM869": 2147484700,
            "csISO159JISX02121990": 2147485219,
            "csISO2022JP": 21,
            "csISO2022JP2": 2147485729,
            "csISO2022KR": 2147485760,
            "csISO42JISC62261978": 2147485220,
            "csISO58GB231280": 2147486000,
            "csISO87JISX0208": 2147485218,
            "csISO88596E": 2147484166,
            "csISO88596I": 2147484166,
            "csISO88598E": 2147484168,
            "csISO88598I": 2147484168,
            "csISOLatin1": 5,
            "csISOLatin2": 9,
            "csISOLatin3": 2147484163,
            "csISOLatin4": 2147484164,
            "csISOLatin5": 2147484169,
            "csISOLatin6": 2147484170,
            "csISOLatinArabic": 2147484166,
            "csISOLatinCyrillic": 2147484165,
            "csISOLatinGreek": 2147484167,
            "csISOLatinHebrew": 2147484168,
            "csJISEncoding": 2147485730,
            "csKOI8R": 2147486210,
            "csKSC56011987": 2147484706,
            "csMacintosh": 30,
            "csPC775Baltic": 2147484678,
            "csPC850Multilingual": 2147484688,
            "csPC862LatinHebrew": 2147484695,
            "csPC8CodePage437": 2147484672,
            "csPCp852": 2147484690,
            "csShiftJIS": 8,
            "csUCS4": 2348810496,
            "csUnicode": 10,
            "csUnicode11": 10,
            "csUnicode11UTF7": 2214592768,
            "csVISCII": 2147486215,
            "csWindows31J": 8,
            "csWindows31Latin1": 12,
            "csWindows31Latin2": 15,
            "csWindows31Latin5": 14,
            "cyrillic": 2147483655,
            "ebcdic-cp-ca": 2147486722,
            "ebcdic-cp-nl": 2147486722,
            "ebcdic-cp-us": 2147486722,
            "ebcdic-cp-wt": 2147486722,
            "ECMA-114": 2147484166,
            "ECMA-118": 2147484167,
            "ELOT_928": 2147484167,
            "EUC-JP": 3,
            "EUC-KR": 2147486016,
            "Extended_UNIX_Code_Packed_Format_for_Japanese": 3,
            "GB18030": 2147485234,
            "GB2312": 2147486000,
            "GBK": 2147485233,
            "GB_2312-80": 2147486000,
            "greek": 2147483654,
            "greek8": 2147484167,
            "hebrew": 2147483653,
            "HZ-GB-2312": 2147486213,
            "IBM037": 2147486722,
            "IBM367": 1,
            "IBM437": 2147484672,
            "IBM775": 2147484678,
            "IBM819": 5,
            "IBM850": 2147484688,
            "IBM851": 2147484689,
            "IBM852": 2147484690,
            "IBM855": 2147484691,
            "IBM857": 2147484692,
            "IBM860": 2147484693,
            "IBM861": 2147484694,
            "IBM862": 2147484695,
            "IBM863": 2147484696,
            "IBM864": 2147484697,
            "IBM865": 2147484698,
            "IBM866": 2147484699,
            "IBM869": 2147484700,
            "ISO-10646-UCS-2": 10,
            "ISO-10646-UCS-4": 2348810496,
            "ISO-2022-CN": 2147485744,
            "ISO-2022-CN-EXT": 2147485745,
            "ISO-2022-JP": 21,
            "ISO-2022-JP-2": 2147485729,
            "ISO-2022-KR": 2147485760,
            "ISO-8859-1": 5,
            "ISO-8859-1-Windows-3.0-Latin-1": 5,
            "ISO-8859-1-Windows-3.1-Latin-1": 5,
            "ISO-8859-10": 2147484170,
            "ISO-8859-13": 2147484173,
            "ISO-8859-14": 2147484174,
            "ISO-8859-15": 2147484175,
            "ISO-8859-16": 2147484176,
            "ISO-8859-2": 9,
            "ISO-8859-2-Windows-Latin-2": 9,
            "ISO-8859-3": 2147484163,
            "ISO-8859-4": 2147484164,
            "ISO-8859-5": 2147484165,
            "ISO-8859-6": 2147484166,
            "ISO-8859-6-E": 2147484166,
            "ISO-8859-6-I": 2147484166,
            "ISO-8859-7": 2147484167,
            "ISO-8859-8": 2147484168,
            "ISO-8859-8-E": 2147484168,
            "ISO-8859-8-I": 2147484168,
            "ISO-8859-9": 2147484169,
            "ISO-8859-9-Windows-Latin-5": 2147484169,
            "iso-ir-100": 5,
            "iso-ir-101": 9,
            "iso-ir-109": 2147484163,
            "iso-ir-110": 2147484164,
            "iso-ir-126": 2147484167,
            "iso-ir-127": 2147484166,
            "iso-ir-138": 2147484168,
            "iso-ir-144": 2147484165,
            "iso-ir-148": 2147484169,
            "iso-ir-149": 2147484706,
            "iso-ir-157": 2147484170,
            "iso-ir-159": 2147485219,
            "iso-ir-226": 2147484176,
            "iso-ir-42": 2147485220,
            "iso-ir-58": 2147486000,
            "iso-ir-6": 1,
            "ISO646-US": 1,
            "ISO_646.irv:1983": 1,
            "ISO_646.irv:1991": 1,
            "ISO_8859-1": 5,
            "ISO_8859-10:1992": 2147484170,
            "ISO_8859-15": 2147484175,
            "ISO_8859-16": 2147484176,
            "ISO_8859-16:2001": 2147484176,
            "ISO_8859-1:1987": 5,
            "ISO_8859-2": 9,
            "ISO_8859-2:1987": 9,
            "ISO_8859-3": 2147484163,
            "ISO_8859-3:1988": 2147484163,
            "ISO_8859-4": 2147484164,
            "ISO_8859-4:1988": 2147484164,
            "ISO_8859-5": 2147484165,
            "ISO_8859-5:1988": 2147484165,
            "ISO_8859-6": 2147484166,
            "ISO_8859-6-E": 2147484166,
            "ISO_8859-6-I": 2147484166,
            "ISO_8859-6:1987": 2147484166,
            "ISO_8859-7": 2147484167,
            "ISO_8859-7:1987": 2147484167,
            "ISO_8859-8": 2147484168,
            "ISO_8859-8-E": 2147484168,
            "ISO_8859-8-I": 2147484168,
            "ISO_8859-8:1988": 2147484168,
            "ISO_8859-9": 2147484169,
            "ISO_8859-9:1989": 2147484169,
            "JIS_C6226-1978": 2147485220,
            "JIS_C6226-1983": 2147485218,
            "JIS_Encoding": 2147485730,
            "JIS_X0201": 2147485216,
            "JIS_X0208-1983": 2147485218,
            "JIS_X0212-1990": 2147485219,
            "KOI8-R": 2147486210,
            "KOI8-U": 2147486216,
            "korean": 2147483651,
            "KSC_5601": 2147484706,
            "KS_C_5601-1987": 2147484706,
            "KS_C_5601-1989": 2147484706,
            "l1": 5,
            "l10": 2147484176,
            "l2": 9,
            "l3": 2147484163,
            "l4": 2147484164,
            "l5": 2147484169,
            "l6": 2147484170,
            "Latin-9": 2147484175,
            "latin1": 5,
            "latin10": 2147484176,
            "latin2": 9,
            "latin3": 2147484163,
            "latin4": 2147484164,
            "latin5": 2147484169,
            "latin6": 2147484170,
            "mac": 30,
            "macintosh": 30,
            "MS936": 2147484705,
            "MS_Kanji": 8,
            "Shift_JIS": 2147486209,
            "TIS-620": 2147484701,
            "UNICODE-1-1": 10,
            "UNICODE-1-1-UTF-7": 2214592768,
            "us": 1,
            "US-ASCII": 1,
            "UTF-16": 10,
            "UTF-16BE": 2415919360,
            "UTF-16LE": 2483028224,
            "UTF-32": 2348810496,
            "UTF-32BE": 2550137088,
            "UTF-32LE": 2617245952,
            "UTF-7": 2214592768,
            "UTF-8": 4,
            "VISCII": 2147486215,
            "windows-1250": 15,
            "windows-1251": 11,
            "windows-1252": 12,
            "windows-1253": 13,
            "windows-1254": 14,
            "windows-1255": 2147484933,
            "windows-1256": 2147484934,
            "windows-1257": 2147484935,
            "windows-1258": 2147484936,
            "Windows-31J": 8,
            "windows-936": 2147484705,
            "X0201": 2147485216,
            "x0208": 2147485218,
            "x0212": 2147485219,
            ]
        
        public static func encodingNameToStringEncoding(_ name: String) -> String.Encoding? {
            guard let rawValue = NAMED_ENCODING_MAP[name] else { return nil }
            return String.Encoding(rawValue: rawValue)
        }
        
        #endif
        
        
    }
    
}
