import XCTest
import Dispatch
import LittleWebServer
@testable import WebRequest
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
#endif


#if swift(>=5.5) && !_runtime(_ObjC)
extension XCTestCase {
    func runAsyncTest(
        named testName: String = #function,
        in file: StaticString = #file,
        at line: UInt = #line,
        withTimeout timeout: TimeInterval = 10,
        test: @escaping () async throws -> Void
    ) {
        var thrownError: Error?
        let errorHandler = { thrownError = $0 }
        let expectation = expectation(description: testName)

        Task {
            do {
                try await test()
            } catch {
                errorHandler(error)
            }

            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        if let error = thrownError {
            XCTFail(
                "Async error thrown: \(error)",
                file: file,
                line: line
            )
        }
    }
}
#endif

#if !swift(>=5.0)
fileprivate extension DispatchSemaphore {
    func fulfill() {
        self.signal()
    }
}
#endif

extension URL {
    func appendingQueryItem(_ name: String, withValue value: String) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        if components.queryItems == nil { components.queryItems = [] }
        if let idx = components.queryItems?.firstIndex(where: { return $0.name == name }) {
            components.queryItems?.remove(at: idx)
            components.queryItems?.insert(URLQueryItem(name: name, value: value), at: idx)
        } else {
            components.queryItems?.append(URLQueryItem(name: name, value: value))
        }
        return components.url!
    }
    func appendingQueryItem(_ item: String) -> URL {
        guard !item.contains("=") else {
            let strComponents = item.split(separator: "=").map(String.init)
            return self.appendingQueryItem(strComponents[0], withValue: strComponents[1])
        }
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        if components.queryItems == nil { components.queryItems = [] }
        if let idx = components.queryItems?.firstIndex(where: { return $0.name == item }) {
            components.queryItems?.remove(at: idx)
            components.queryItems?.insert(URLQueryItem(name: item, value: nil), at: idx)
        } else {
            components.queryItems?.append(URLQueryItem(name: item, value: nil))
        }
        return components.url!
    }
}

final class WebRequestTests: XCTestCase {
    static var server: LittleWebServer!
    
    public static var testURLBase: URL {
        
        var urlBase = self.server.listeners.first(as: LittleWebServerTCPIPListener.self)!.url
        if urlBase.host == "0.0.0.0" {
            var urlString = urlBase.absoluteString
            urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1")
            urlBase = URL(string: urlString)!
        }
        
        return urlBase
    }
    
    static var testURLSearch: URL { return URL(string: "/search", relativeTo: testURLBase)! }
    
    static var uploadedData: [String: Data] = [:]
    
    
    var testURLBase: URL { return WebRequestTests.testURLBase }
    var testURLSearch: URL { return WebRequestTests.testURLSearch }
    
    
    override class func setUp() {
        super.setUp()
        
        var retryCount: Int = 0
        var retry: Bool = true
        repeat {
            do {
                let listener = try LittleWebServerHTTPListener(specificIP: .anyIPv4,
                                                               port: .firstAvailable,
                                                               reuseAddr: true,
                                                               maxBacklogSize: LittleWebServerSocketListener.DEFAULT_MAX_BACK_LOG_SIZE,
                                                               enablePortSharing: true)
                
                WebRequestTests.server = LittleWebServer(listener)
                retry = false
            } catch LittleWebServerSocketConnection.SocketError.socketBindFailed(let error) {
                if let sysError = error as? LittleWebServerSocketSystemError,
                   sysError == .addressAlreadyInUse && retryCount < 3 {
                    retryCount += 1
                } else {
                    print("Failed to create listener: \(error)")
                    retry = false
                }
            } catch {
                print("Failed to create listener: \(error)")
                retry = false
            }
        } while retry
        
        
        WebRequestTests.server?.defaultHost["/search"] = {
            (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            let initialValue = "Query"
            var rtn: String = initialValue
            
            // Allow the client to slow down the response
            if let q = request.queryItems.first(where: { return $0.name == "sleep" }),
               let qValue = q.value,
               let dValue = Double(qValue) {
                Thread.sleep(forTimeInterval: dValue)
            }
            
            if let param = request.queryItems.first(where: { return $0.name == "q" }) {
                if rtn == initialValue { rtn += "?" }
                else { rtn += "&"}
                
                rtn += "q=" + (param.value ?? "")
            }
            if let param = request.queryItems.first(where: { return $0.name == "start" }) {
                if rtn == initialValue { rtn += "?" }
                else { rtn += "&"}
                
                rtn += "start=" + (param.value ?? "")
            }
            return .ok(body: .plainText(rtn))
        }
        
        let eventPrefixData = "{ \"event_type\": \"system\", \"event_count\": ".data(using: .utf8)!
        let eventSuffixData = ", \"event_up\": true }\n".data(using: .utf8)!
        
        WebRequestTests.server?.defaultHost["/events"] = { (request: LittleWebServer.HTTP.Request) -> LittleWebServer.HTTP.Response in
            
            var sleepValue: Double? = nil
            // Allow the client to slow down the response
            if let q = request.queryItems.first(where: { return $0.name == "sleep" }),
               let qValue = q.value,
               let dValue = Double(qValue) {
                sleepValue = dValue
            }
            
            func eventWriter(_ input: LittleWebServerInputStream, _ output: LittleWebServerOutputStream) {
                var count: Int = 0
                let macCount: Int = 100 /*Int.max / * 100 */
                let startDate = Date()
                while self.server.isRunning &&
                      output.isConnected &&
                      count < macCount {
                    
                    count += 1
                    //let dta = eventData.data(using: .utf8)!
                    
                    do {
                        try WebRequest.autoreleasepool {
                            let coutData = "\(count)".data(using: .utf8)!
                            try output.write( eventPrefixData + coutData + eventSuffixData)
                            /*try output.write(eventPrefixData)
                            try output.write("\(count)".data(using: .utf8)!)
                            try output.write(eventSuffixData)*/
                        }
                        
                        //print("[\(self.testId)]: Sent event: \(count - 1)")
                    } catch {
                        if output.isConnected {
                            XCTFail("OH NO: \(error)")
                        }
                        break
                    }
                    if let s = sleepValue {
                        Thread.sleep(forTimeInterval: s)
                    }
                }
                if output.isConnected {
                    // If we're still connected we send a 0 byte line
                    // to indicate that response has ended
                    try? output.write([])
                }
                let endDate = Date()
                let duration = endDate.timeIntervalSince(startDate)
                #if !DOCKER_ALL_BUILD
                print("Server wrote events for \(duration)")
                #endif
            }
            
            return .ok(body: .custom(eventWriter))
        }
        
        
        #if swift(>=5.3)
        let webRequestTestFolder = NSString(string: "\(#filePath)").deletingLastPathComponent
        #else
        let webRequestTestFolder = NSString(string: "\(#file)").deletingLastPathComponent
        #endif
        print("Sharing folder '\(webRequestTestFolder)' at '/testfiles'")
        self.server?.defaultHost.get["/testfiles/"] = LittleWebServer.FSSharing.share(resource: URL(fileURLWithPath: webRequestTestFolder))
        
        self.server?.defaultHost.post["/upload"] = { (request: LittleWebServer.HTTP.Request,
                                                     routeController: LittleWebServer.Routing.Requests.RouteController) -> LittleWebServer.HTTP.Response in
            do {
                if request.uploadedFiles.count > 0 {
                    for file in request.uploadedFiles {
                        self.uploadedData[file.path] = try Data.init(contentsOf: file.location)
                    }
                } else if let contentLength = request.contentLength,
                          contentLength > 0 {
                    self.uploadedData[""] = try request.inputStream.read(exactly: Int(contentLength))
                }
                return .ok(body: .empty)
            } catch {
                return routeController.internalError(for: request,
                                                     error: error,
                                                     message: "Failed to load uploaded data")
            }
        }
        
        
        /// We re-assign the test server port because if it was originally 0 then a randomly selected available port will be used
        //print("Running on port \((try! WebRequestTests.server!))")
        do {
            try WebRequestTests.server?.start()
            print("Server started")
        } catch {
            print("Failed to start server")
        }
    }
    override class func tearDown() {
        print("Stopping server")
        WebRequestTests.server?.stop()
        super.tearDown()
    }
    
    
    
    override func setUp() {
        func sigHandler(_ signal: Int32) -> Void {
            print("A fatal error has occured")
            #if swift(>=4.1) || _runtime(_ObjC)
            Thread.callStackSymbols.forEach { print($0) }
            #endif
            fflush(stdout)
            exit(1)
        }
        signal(4, sigHandler)
    }
    func testSingleRequest() {
        let testURL = testURLSearch.appendingQueryItem("q=Swift")
        
        if true {
            #if _runtime(_ObjC) || swift(>=5.0)
            let requestStartedExpect = self.expectation(description: "requestStarted")
            let requestCompletedExpect = self.expectation(description: "requestCompleted")
            let requestCompletionExpect = self.expectation(description: "requestCompletion")
            #else
            let requestStartedExpect = DispatchSemaphore(value: 0)
            let requestCompletedExpect = DispatchSemaphore(value: 0)
            let requestCompletionExpect = DispatchSemaphore(value: 0)
            #endif
            //print("Creating base session")
            let session = URLSession.usingWebRequestSharedSessionDelegate()
            defer { session.finishTasksAndInvalidate() }
            
            
            //print("Creating request")
            let request = WebRequest.DataRequest(testURL, usingSession: session) { r in
                defer { requestCompletionExpect.fulfill() }
                XCTAssertNil(r.error, "Expected no Error but found '\(r.error as Any)'")
                guard let s = r.responseString() else {
                    XCTFail("Unable to convert resposne into string: \(r.data as Any)")
                    return
                }
                XCTAssertEqual(s, "Query?q=Swift", "Expected response to match")
                
            }
            request.requestStarted = { _ in
                requestStartedExpect.fulfill()
            }
            request.requestCompleted = { _ in
                requestCompletedExpect.fulfill()
            }
            var changedStates: [WebRequest.ChangeState] = []
            request.registerStateChangedHandler { request, from, to in
                changedStates.append(to)
            }
            request.resume()
            request.waitUntilComplete()
            
            #if _runtime(_ObjC) || swift(>=5.0)
            self.wait(for: [requestStartedExpect,
                            requestCompletedExpect,
                            requestCompletionExpect],
                         timeout: 10)
            #else
            if requestStartedExpect.wait(timeout: .now() + 10) == .timedOut {
                XCTFail("Failed expectation request started")
            }
            if requestCompletedExpect.wait(timeout: .now() + 10) == .timedOut {
                XCTFail("Failed expectation request completed")
            }
            if requestCompletionExpect.wait(timeout: .now() + 10) == .timedOut {
                XCTFail("Failed expectation request completion")
            }
            #endif
            
            
            XCTAssertTrue(changedStates.contains(.starting))
            XCTAssertTrue(changedStates.contains(.completed))
            
        }
        if true {
            #if _runtime(_ObjC) || swift(>=5.0)
            let requestStartedExpect = self.expectation(description: "requestStarted")
            let requestCancelledExpect = self.expectation(description: "requestCancelled")
            let requestCompletionExpect = self.expectation(description: "requestCompletion")
            #else
            let requestStartedExpect = DispatchSemaphore(value: 0)
            let requestCancelledExpect = DispatchSemaphore(value: 0)
            let requestCompletionExpect = DispatchSemaphore(value: 0)
            #endif
            
            
            
            let session = URLSession.usingWebRequestSharedSessionDelegate()
            defer { session.finishTasksAndInvalidate() }
            
            
            let request = WebRequest.DataRequest(testURL.appendingQueryItem("sleep=5"), usingSession: session) { r in
                defer { requestCompletionExpect.fulfill() }
                guard let e = r.error else {
                    XCTFail("Missing error value")
                    return
                }
                #if _runtime(_ObjC) || swift(>=4.2)
                XCTAssertEqual((e as NSError).code,
                               NSURLErrorCancelled,
                               "Invalid NS Error Code")
                #else
                if let nsError = e as? NSError {
                    XCTAssertEqual(nsError.code,
                                   NSURLErrorCancelled,
                                   "Invalid NS Error Code")
                } else if let urlError = e as? URLError {
                    XCTAssertEqual(urlError.code,
                                   .cancelled,
                                   "Invalid Error Code")
                } else {
                    XCTFail("Unexpected error: \(e)")
                }
                #endif
                
            }
            request.requestStarted = { _ in
                requestStartedExpect.fulfill()
                request.cancel()
            }
            request.requestCancelled = { _ in
                requestCancelledExpect.fulfill()
            }
            var changedStates: [WebRequest.ChangeState] = []
            request.registerStateChangedHandler { request, from, to in
                changedStates.append(to)
            }
            //print("Starting request")
            request.resume()
            //print("Waiting for request to finish")
            request.waitUntilComplete()
            
            #if _runtime(_ObjC) || swift(>=5.0)
            self.wait(for: [requestStartedExpect,
                            requestCancelledExpect,
                            requestCompletionExpect],
                         timeout: 10)
            #else
            if requestStartedExpect.wait(timeout: .now() + 10) == .timedOut {
                XCTFail("Failed expectation request started")
            }
            if requestCancelledExpect.wait(timeout: .now() + 10) == .timedOut {
                XCTFail("Failed expectation request cancelled")
            }
            if requestCompletionExpect.wait(timeout: .now() + 10) == .timedOut {
                XCTFail("Failed expectation request completion")
            }
            #endif
            
            
            XCTAssertTrue(changedStates.contains(.starting))
            XCTAssertTrue(changedStates.contains(.canceling))
        }
    }
    
#if swift(>=5.5)
    var testAsyncSingleRequestExecuted: Bool = false
    @available(macOS 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func _testAsyncSingleRequest() async {
        self.testAsyncSingleRequestExecuted = false
        let testCount: Int = 5
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        for _ in 0..<testCount {
            
            
            // Test Basic Request
            let testURL = self.testURLSearch.appendingQueryItem("q=Swift")
            
            let request = WebRequest.DataRequest(testURL, usingSession: session)
            
            
            let r = await request.safeExecute()
            self.testAsyncSingleRequestExecuted = true
            XCTAssertNil(r.error, "Expected no Error but found '\(r.error as Any)'")
            guard let s = r.responseString() else {
                XCTFail("Unable to convert response into string: \(r.data as Any)")
                return
            }
            XCTAssertEqual(s, "Query?q=Swift", "Expected response to match")
            XCTAssertEqual(request.state, .completed)
            
            // Test Cancelled Request
            
            // set new request that will sleep for 3 seconds befor returning response
            let requestCancelled = WebRequest.DataRequest(testURL.appendingQueryItem("sleep=3"), usingSession: session)
            requestCancelled.requestStarted = { _ in
                print("Request started")
                DispatchQueue.global().async {
                    Thread.sleep(forTimeInterval: 0.5)
                    print("Cancelling request")
                    requestCancelled.cancel()
                }
            }
            requestCancelled.requestCompleted = { _ in
                print("Request completed")
            }
            do {
                let r = try await requestCancelled.execute()
                XCTFail("Expected Error to be thrown:\n\(r)")
            } catch let urlError as URLError {
                XCTAssertEqual(urlError.errorCode, NSURLErrorCancelled)
            } catch let nsError as NSError {
                XCTAssertEqual(nsError.code, NSURLErrorCancelled)
            } catch {
                XCTFail("Unexpected error type \(error)")
            }
            
            XCTAssertEqual(requestCancelled.state, .canceling)
            
            let inlineResults = await WebRequest.DataRequest(testURL, usingSession: session).safeExecute()
            
            
            guard let s = inlineResults.responseString() else {
                XCTFail("Unable to convert response into string: \(r.data as Any)")
                return
            }
            XCTAssertEqual(s, "Query?q=Swift", "Expected response to match")
            
            
            
        }
    }
    #if _runtime(_ObjC)
    @available(macOS 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testAsyncSingleRequest() async {
        self.testAsyncSingleRequestExecuted = false
        await self._testAsyncSingleRequest()
        XCTAssertTrue(self.testAsyncSingleRequestExecuted,
                      "Test '_testAsyncSingleRequest' was not executed")
    }
    #else
    func testAsyncSingleRequest() {
        self.testAsyncSingleRequestExecuted = false
        runAsyncTest {
            await self._testAsyncSingleRequest()
        }
        XCTAssertTrue(self.testAsyncSingleRequestExecuted,
                      "Test '_testAsyncSingleRequest' was not executed")
    }
    #endif
#endif
    
    func testMultiRequest() {
        func sigHandler(_ signal: Int32) -> Void {
            print("SIG: 4")
            Thread.callStackSymbols.forEach{print($0)}
            fflush(stdout)
            exit(1)
        }
        signal(4, sigHandler)
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        var requests: [URL] = []
        for i in 0..<5 {
            var url: URL = testURLSearch.appendingQueryItem("q=Swift")
            if i > 0 {
                url = url.appendingQueryItem("start=\(i * 10)")
            }
            requests.append(url)
        }
        let sig = DispatchSemaphore(value: 0)
        
        let request = WebRequest.GroupRequest(requests,
                                              usingSession: session,
                                              maxConcurrentRequests: 5) { rA in
            #if !DOCKER_ALL_BUILD
            print("Finished grouped request")
            #endif
            for (i, r) in rA.enumerated() {
                guard let request = r as? WebRequest.DataRequest else {
                    XCTFail("[\(i)] Expected 'WebRequest.DataRequest' but found '\(type(of: r))'")
                    continue
                }
                var responseLine: String = "[\(i)] \(request.originalRequest!.url!.absoluteString): \(request.state) "
                if let r = request.response as? HTTPURLResponse { responseLine += " - \(r.statusCode)" }
                else if let e = request.results.error { responseLine += " - \(type(of: e)): \(e)" }
                guard let responseString = request.results.responseString() else {
                    XCTFail("[\(i)]: Unable to convert response into string: \(request.results.data as Any)")
                    continue
                }
                var testCase: String = "Query?q=Swift"
                if i > 0 { testCase += "&start=\(i * 10)" }
                XCTAssertEqual(responseString, testCase, "[\(i)]: Expected response to match")
                #if !DOCKER_ALL_BUILD
                print(responseLine)
                fflush(stdout)
                #endif
            }
            sig.signal()
        }
        request.requestStarted = { r in
            #if !DOCKER_ALL_BUILD
            print("Starting grouped request")
            #endif
        }
        request.singleRequestStarted = { gR, i, r in
            guard let request = r as? WebRequest.DataRequest else { return }
            #if !DOCKER_ALL_BUILD
            print("Staring [\(i)] \(request.originalRequest!.url!.absoluteString)")
            #endif
        }
        request.singleRequestCompleted = { gR, i, r in
            guard let request = r as? WebRequest.DataRequest else { return }
            let responseSize = request.results.data?.count ?? 0
            let responseCode = (request.response as? HTTPURLResponse)?.statusCode ?? 0
            #if !DOCKER_ALL_BUILD
            print("Finished [\(i)] \(request.originalRequest!.url!.absoluteString) - \(responseCode) - \(request.state) - Size: \(responseSize)")
            #endif
        }
        request.resume()
        request.waitUntilComplete()
        sig.wait()
    }
    
    func testMultiRequestEventOnCompleted() {
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        var requests: [URL] = []
        for i in 0..<5 {
            var url: URL = testURLSearch.appendingQueryItem("q=Swift")
            if i > 0 {
                url = url.appendingQueryItem("start=\(i * 10)")
            }
            requests.append(url)
        }
        let sig = DispatchSemaphore(value: 0)
        let request =  WebRequest.GroupRequest(requests, usingSession: session, maxConcurrentRequests: 5)
        request.singleRequestCompleted = {gR, i, r in
            guard let request = r as? WebRequest.DataRequest else { return }
            
            guard let responseString = request.results.responseString() else {
                XCTFail("[\(i)]: Unable to convert resposne into string: \(request.results.data as Any)")
                return
            }
            var testCase: String = "Query?q=Swift"
            if i > 0 { testCase += "&start=\(i * 10)" }
            XCTAssertEqual(responseString, testCase, "[\(i)]: Expected response to match")
            #if !DOCKER_ALL_BUILD
            print("[\(i)] \(request.originalRequest!.url!.absoluteString) - \((request.response as! HTTPURLResponse).statusCode)")
            let preClearData = (request.results.data != nil) ? "\(request.results.data!)" : "nil"
            print("[\(i)] \(request.originalRequest!.url!.absoluteString) - \(preClearData)")
            request.emptyResultsData()
            let postClearData = (request.results.data != nil) ? "\(request.results.data!)" : "nil"
            print("[\(i)] \(request.originalRequest!.url!.absoluteString) - \(postClearData)")
            #endif
            
            fflush(stdout)
        }
        request.requestCompleted = { _ in
            sig.signal()
        }
        
        request.resume()
        request.waitUntilComplete()
        sig.wait()
    }
    
    func testMultiRequestEventOnCompletedWithMaxConcurrentCount() {
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        var requests: [URL] = []
        for i in 0..<5 {
            var url: URL = testURLSearch.appendingQueryItem("q=Swift")
            if i > 0 {
                url = url.appendingQueryItem("start=\(i * 10)")
            }
            requests.append(url)
        }
        let sig = DispatchSemaphore(value: 0)
        let request =  WebRequest.GroupRequest(requests,
                                               usingSession: session,
                                               maxConcurrentRequests: 1)
        request.singleRequestStarted = {gR, i, r in
             guard let request = r as? WebRequest.DataRequest else { return }
             #if !DOCKER_ALL_BUILD
             print("[\(i)] \(request.originalRequest!.url!.absoluteString) - Started")
             #endif
        }
        request.singleRequestCompleted = {gR, i, r in
            guard let request = r as? WebRequest.DataRequest else { return }
            
            guard let responseString = request.results.responseString() else {
                XCTFail("[\(i)]: Unable to convert resposne into string: \(request.results.data as Any)")
                return
            }
            var testCase: String = "Query?q=Swift"
            if i > 0 { testCase += "&start=\(i * 10)" }
            XCTAssertEqual(responseString, testCase, "[\(i)]: Expected response to match")
            #if !DOCKER_ALL_BUILD
            print("[\(i)] \(request.originalRequest!.url!.absoluteString) - \((request.response as! HTTPURLResponse).statusCode)")
            let preClearData = (request.results.data != nil) ? "\(request.results.data!)" : "nil"
            print("[\(i)] \(request.originalRequest!.url!.absoluteString) - \(preClearData)")
            request.emptyResultsData()
            let postClearData = (request.results.data != nil) ? "\(request.results.data!)" : "nil"
            print("[\(i)] \(request.originalRequest!.url!.absoluteString) - \(postClearData)")
            fflush(stdout)
            #endif
        }
        request.requestCompleted = { _ in
            sig.signal()
        }
        
        request.resume()
        request.waitUntilComplete()
        sig.wait()
    }
    
    func testRepeatRequest() {
        
        func repeatHandler(_ request: WebRequest.RepeatedDataRequest<Void>,
                           _ results: WebRequest.DataRequest.Results,
                           _ repeatCount: Int) -> WebRequest.RepeatedDataRequest<Void>.RepeatResults {
            
            if let responseString = results.responseString() {
                XCTAssertEqual(responseString, "Query", "[\(repeatCount)]: Expected response to match")
            } else {
                XCTFail("[\(repeatCount)]: Unable to convert resposne into string: \(results.data as Any)")
            }
           
            #if !DOCKER_ALL_BUILD
            print("[\(repeatCount)] - \(results.originalURL!.absoluteString) - Finished")
            #endif
            if repeatCount < 5 { return WebRequest.RepeatedDataRequest<Void>.RepeatResults.repeat }
            else { return WebRequest.RepeatedDataRequest<Void>.RepeatResults.results(nil) }
        }
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        let req = testURLSearch
        let sig = DispatchSemaphore(value: 0)
        let r = WebRequest.RepeatedDataRequest<Void>(req,
                                                     usingSession: session,
                                                     repeatInterval: 1,
                                                     repeatHandler: repeatHandler) { rs, r, e in
            
            #if !DOCKER_ALL_BUILD
            print("All Done!")
            #endif
            
             sig.signal()
        }
        
        r.resume()
        r.waitUntilComplete()
        sig.wait()
        
        
    }
    
    /*
    // Long repeat request to monitor memory usage
    func testRepeatRequestLong() {
        
        func repeatHandler(_ request: WebRequest.RepeatedDataRequest<Void>,
                           _ results: WebRequest.DataRequest.Results,
                           _ repeatCount: Int) -> WebRequest.RepeatedDataRequest<Void>.RepeatResults {
            
            /*if let responseString = results.responseString() {
                XCTAssertEqual(responseString, "Query", "[\(repeatCount)]: Expected response to match")
            } else {
                XCTFail("[\(repeatCount)]: Unable to convert resposne into string: \(results.data as Any)")
            }*/
           
            
            //print("[\(repeatCount)] - \(results.originalURL!.absoluteString) - Finished")
            return WebRequest.RepeatedDataRequest<Void>.RepeatResults.repeat
            //return (repeat: rep, results: results)
        }
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
     
        let req = testURLSearch
        let sig = DispatchSemaphore(value: 0)
        let r = WebRequest.RepeatedDataRequest<Void>(req,
                                                     usingSession: session,
                                                     repeatInterval: 1,
                                                     repeatHandler: repeatHandler) { rs, r, e in
            
            
            print("All Done!")
            
             sig.signal()
        }
        
        r.resume()
        r.waitUntilComplete()
        sig.wait()
        
        
    }
    */
    
    func testRepeatRequestCancelled() {
        func repeatHandler(_ request: WebRequest.RepeatedDataRequest<Void>,
                           _ results: WebRequest.DataRequest.Results,
                           _ repeatCount: Int) -> WebRequest.RepeatedDataRequest<Void>.RepeatResults {
            
            if let responseString = results.responseString() {
                XCTAssertEqual(responseString, "Query", "[\(repeatCount)]: Expected response to match")
            } else {
                XCTFail("[\(repeatCount)]: Unable to convert resposne into string: \(results.data as Any)")
            }
            #if !DOCKER_ALL_BUILD
            print("[\(repeatCount)] - \(results.originalURL!.absoluteString) - Finished")
            #endif
            if repeatCount == 3 { request.cancel() }
            if repeatCount < 5 { return WebRequest.RepeatedDataRequest<Void>.RepeatResults.repeat }
            else { return WebRequest.RepeatedDataRequest<Void>.RepeatResults.results(nil) }
            //return (repeat: rep, results: results)
        }
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        let req = testURLSearch
        let sig = DispatchSemaphore(value: 0)
        let r = WebRequest.RepeatedDataRequest<Void>(req,
                                                     usingSession: session,
                                                     repeatInterval: 1,
                                                     repeatHandler: repeatHandler) { rs, r, e in
            #if !DOCKER_ALL_BUILD
            print("All Done!")
            #endif
            
            sig.signal()
        }
        r.resume()
        r.waitUntilComplete()
        sig.wait()
    }
    
    func testRepeatRequestUpdateURL() {
        func repeatHandler(_ request: WebRequest.RepeatedDataRequest<Void>,
                           _ results: WebRequest.DataRequest.Results,
                           _ repeatCount: Int) -> WebRequest.RepeatedDataRequest<Void>.RepeatResults {
            if let responseString = results.responseString() {
                var testCase = "Query"
                if repeatCount > 0 {
                    testCase += "?start=\(repeatCount * 10)"
                }
                XCTAssertEqual(responseString, testCase, "[\(repeatCount)]: Expected response to match")
            } else {
                
                XCTFail("[\(repeatCount)]: Unable to convert resposne into string: \(results.data as Any) - error: \(results.error as Any)")
            }
            #if !DOCKER_ALL_BUILD
            print("[\(repeatCount)] - \(results.originalURL!.absoluteString) - Finished")
            #endif
            if repeatCount < 5 { return WebRequest.RepeatedDataRequest<Void>.RepeatResults.repeat }
            else { return WebRequest.RepeatedDataRequest<Void>.RepeatResults.results(nil) }
            //return (repeat: rep, results: results)
        }
        func updateRequestDetails(_ parameters: inout [URLQueryItem]?,
                                  _ headers: inout [String: String]?,
                                  _ repeatCount: Int) {
            var params = parameters ?? []
            if let idx = params.firstIndex(where: { return $0.name == "start" }) {
                params.remove(at: idx)
            }
            if repeatCount > 0 {
                params.append(URLQueryItem(name: "start", value: "\(repeatCount * 10)"))
            }
            if params.count > 0 {
                parameters = params
            }
            
        }
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        let req = testURLSearch
        let sig = DispatchSemaphore(value: 0)
        let r = WebRequest.RepeatedDataRequest<Void>(req,
                                                     updateRequestDetails: updateRequestDetails,
                                                     usingSession: session,
                                                     repeatInterval: 1,
                                                     repeatHandler: repeatHandler) { rs, r, e in
            
            #if !DOCKER_ALL_BUILD
            print("All Done!")
            #endif
             sig.signal()
        }
        
        r.resume()
        r.waitUntilComplete()
        sig.wait()
    }
    
    func testRepeatRequestUpdateURLCancelled() {
        func repeatHandler(_ request: WebRequest.RepeatedDataRequest<Void>,
                           _ results: WebRequest.DataRequest.Results,
                           _ repeatCount: Int) -> WebRequest.RepeatedDataRequest<Void>.RepeatResults {
            
            if let responseString = results.responseString() {
                
                var testCase = "Query"
                if repeatCount > 0 {
                    testCase += "?start=\(repeatCount * 10)"
                }
                XCTAssertEqual(responseString, testCase, "[\(repeatCount)]: Expected response to match")
            } else {
                XCTFail("[\(repeatCount)]: Unable to convert resposne into string: \(results.data as Any)")
            }
            #if !DOCKER_ALL_BUILD
            print("[\(repeatCount)] - \(results.originalURL!.absoluteString) - Finished")
            #endif
            if repeatCount == 3 { request.cancel() }
            if repeatCount < 5 { return WebRequest.RepeatedDataRequest<Void>.RepeatResults.repeat }
            else { return WebRequest.RepeatedDataRequest<Void>.RepeatResults.results(nil) }
            //return (repeat: rep, results: results)
        }
        func updateRequestDetails(_ parameters: inout [URLQueryItem]?,
                                  _ headers: inout [String: String]?,
                                  _ repeatCount: Int) {
            var params = parameters ?? []
            if let idx = params.firstIndex(where: { return $0.name == "start" }) {
                params.remove(at: idx)
            }
            if repeatCount > 0 {
                params.append(URLQueryItem(name: "start", value: "\(repeatCount * 10)"))
            }
            if params.count > 0 {
                parameters = params
            }
            
        }
        
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        let req = testURLSearch
        let sig = DispatchSemaphore(value: 0)
        let r = WebRequest.RepeatedDataRequest<Void>(req,
                                                     updateRequestDetails: updateRequestDetails,
                                                     usingSession: session,
                                                     repeatInterval: 1,
                                                     repeatHandler: repeatHandler) { rs, r, e in
            
            #if !DOCKER_ALL_BUILD
            print("All Done!")
            #endif
             sig.signal()
        }
        
        r.resume()
        r.waitUntilComplete()
        sig.wait()
    }
    
#if swift(>=5.5)
    var testAsyncRepeatRequestExecuted: Bool = false
    @available(macOS 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func _testAsyncRepeatRequest() async {
        self.testAsyncRepeatRequestExecuted = false
        
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        let req = testURLSearch
        
        func repeatHandler(_ request: WebRequest.RepeatedDataRequest<String>,
                           _ results: WebRequest.DataRequest.Results,
                           _ repeatCount: Int) -> WebRequest.RepeatedDataRequest<String>.RepeatResults {
            if repeatCount < 5 {
                return .repeat
            } else {
                return .results(results.responseString())
            }
        }
        
        var request: WebRequest.RepeatedDataRequest<String>!
        request = WebRequest.RepeatedDataRequest<String>(req,
                                                         usingSession: session,
                                                         repeatInterval: 1,
                                                         repeatHandler: repeatHandler) { rs, r, e in
            
            #if !DOCKER_ALL_BUILD
            print("[\(self)][testAsyncRepeatRequest]: All Done!")
            print("[\(self)][testAsyncRepeatRequest][Duration]: \(request.requestCompleteDuration ?? -1.0)")
            #endif
            
             
        }
        
        let r =  await request.safeExecute()
        self.testAsyncRepeatRequestExecuted = true
        // do verification here
        guard let s = r.object else {
            XCTFail("No response string")
            return
        }
        #if !DOCKER_ALL_BUILD
        print(s)
        #endif
        
    }
    #if _runtime(_ObjC)
    @available(macOS 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testAsyncRepeatRequest() async {
        self.testAsyncRepeatRequestExecuted = false
        await self._testAsyncRepeatRequest()
        XCTAssertTrue(self.testAsyncRepeatRequestExecuted,
                      "Test '_testAsyncRepeatRequest' was not executed")
    }
    #else
    func testAsyncRepeatRequest() {
        self.testAsyncRepeatRequestExecuted = false
        runAsyncTest {
            await self._testAsyncRepeatRequest()
        }
        XCTAssertTrue(self.testAsyncRepeatRequestExecuted,
                      "Test '_testAsyncRepeatRequest' was not executed")
    }
    #endif
#endif
    
    func testDownloadFile() {
        
        
        let filePath = "\(#file)"
        let fileName = NSString(string: filePath).lastPathComponent
        
        let downloadFileURL = testURLBase
            .appendingPathComponent("/testfiles")
            .appendingPathComponent(fileName)
        
        let sig = DispatchSemaphore(value: 0)
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        #if !DOCKER_ALL_BUILD
        print("Trying to download '\(downloadFileURL.absoluteString)'")
        #endif
        
        let request = WebRequest.DownloadRequest(downloadFileURL, usingSession: session) { r in
            XCTAssertNil(r.error, "Expected no Error but found '\(r.error as Any)'")
            guard let downloadLocation = r.location else {
                XCTFail("No download file")
                sig.signal()
                return
            }
            #if !DOCKER_ALL_BUILD
            print("Download Location: '\(downloadLocation.absoluteString)'")
            #endif
            let originalData = try! Data(contentsOf: URL(fileURLWithPath: filePath))
            let downloadData = try! Data(contentsOf: downloadLocation)
            
            XCTAssertEqual(originalData, downloadData, "Download file does not match orignal file")
            
            try? FileManager.default.removeItem(at: downloadLocation)
            
            sig.signal()
        }
        
        request.resume()
        request.waitUntilComplete()
        sig.wait()
        
        
    }
    
    func testUploadFile() {
        let filePath = "\(#file)"
        let fileURL = URL(fileURLWithPath: filePath)
        let uploadURL = testURLBase
            .appendingPathComponent("/upload")
        
        let sig = DispatchSemaphore(value: 0)
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        let request = WebRequest.UploadRequest(uploadURL,
                                               fromFile: fileURL,
                                               usingSession: session) { r in
            XCTAssertNil(r.error, "Expected no Error but found '\(r.error as Any)'")
            XCTAssertNotNil(r.results, "Expected Data response to not be nil")
            XCTAssertEqual(r.results?.count, 0, "Expected Data response to be empty")
            
            
            let originalData = try! Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent
            guard let uploadedData = WebRequestTests.uploadedData[fileName] ?? WebRequestTests.uploadedData[""] else {
                XCTFail("Unable to find uploaded data for '\(fileName)'")
                #if !DOCKER_ALL_BUILD
                print("Current upload count: \( WebRequestTests.uploadedData.count)")
                for up in WebRequestTests.uploadedData.keys {
                    print(up)
                }
                #endif
                sig.signal()
                return
            }
            
            XCTAssertEqual(originalData, uploadedData, "Download file does not match orignal file")
            
            sig.signal()
        }
        request.resume()
        request.waitUntilComplete()
        sig.wait()
    }
    
    func testStreamedEvents() {
        
        let eventsURL = testURLBase.appendingPathComponent("/events").appendingQueryItem("sleep=0.1")
        
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        defer { session.finishTasksAndInvalidate() }
        
        let eventRequest = URLRequest(url: eventsURL,
                                      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                      timeoutInterval: .infinity)
        #if !DOCKER_ALL_BUILD
        print("Starting to stream events from '\(eventsURL.absoluteString)'")
        #endif
        var didReceiveEvent: Bool = false
        let request = WebRequest.DataRequest(eventRequest, usingSession: session)
        request.addDidReceiveDataHandler { _, dataRequest, data in
            didReceiveEvent = true
            guard let str = String(data: data, encoding: .utf8) else {
                XCTFail("Failed to convert data to string")
                return
            }
            #if !DOCKER_ALL_BUILD
            print(str, terminator: "")
            #endif
        }
        
        let timeout: TimeInterval = 2//20
        
        let waitQueue = DispatchQueue(label: "EventRequestWait")
        waitQueue.async {
            // we want to let the events to stream for a while before we cancel the request to stop the stream
            Thread.sleep(forTimeInterval: timeout)
            #if !DOCKER_ALL_BUILD
            print("Stopping request")
            #endif
            request.cancel()
        }
        request.resume()
        request.waitUntilComplete()
        XCTAssert(didReceiveEvent, "No events were received")
    }
    
    func testDeinitHandler() {
        let testURL = testURLSearch.appendingQueryItem("q=Swift")
        let session = URLSession.usingWebRequestSharedSessionDelegate()
        var request: WebRequest.DataRequest?  = WebRequest.DataRequest(testURL,
                                                                       usingSession: session)
        let semaphore = DispatchSemaphore(value: 0)
        request?.registerDeinitHandler { _ in
            session.finishTasksAndInvalidate()
            semaphore.signal()
        }
        
        request = nil
        if semaphore.wait(timeout: .now() + 5.0) != .success {
            XCTFail("Failed to signal requst dinit in allocated time")
        }
        
    }
    
    #if _runtime(_ObjC)
    func testEncodingNames() {
        let encodingString: [String] = ["1",
                    "437",
                    "850",
                    "851",
                    "852",
                    "855",
                    "857",
                    "860",
                    "861",
                    "862",
                    "863",
                    "865",
                    "866",
                    "869",
                    "904",
                    "Adobe-Standard-Encoding",
                    "Adobe-Symbol-Encoding",
                    "ANSI_X3.110-1983",
                    "ANSI_X3.4-1968",
                    "ANSI_X3.4-1986",
                    "arabic",
                    "arabic7",
                    "ASCII",
                    "ASMO-708",
                    "ASMO_449",
                    "Big5",
                    "Big5-HKSCS",
                    "BOCU-1",
                    "BS_4730",
                    "BS_viewdata",
                    "ca",
                    "CCSID00858",
                    "CCSID00924",
                    "CCSID01140",
                    "CCSID01141",
                    "CCSID01142",
                    "CCSID01143",
                    "CCSID01144",
                    "CCSID01145",
                    "CCSID01146",
                    "CCSID01147",
                    "CCSID01148",
                    "CCSID01149",
                    "CESU-8",
                    "chinese",
                    "cn",
                    "cp-ar",
                    "cp-gr",
                    "cp-is",
                    "CP00858",
                    "CP00924",
                    "CP01140",
                    "CP01141",
                    "CP01142",
                    "CP01143",
                    "CP01144",
                    "CP01145",
                    "CP01146",
                    "CP01147",
                    "CP01148",
                    "CP01149",
                    "cp037",
                    "cp038",
                    "CP1026",
                    "CP154",
                    "CP273",
                    "CP274",
                    "cp275",
                    "CP278",
                    "CP280",
                    "cp281",
                    "CP284",
                    "CP285",
                    "cp290",
                    "cp297",
                    "cp367",
                    "cp420",
                    "cp423",
                    "cp424",
                    "cp437",
                    "CP500",
                    "cp775",
                    "CP819",
                    "cp850",
                    "cp851",
                    "cp852",
                    "cp855",
                    "cp857",
                    "cp860",
                    "cp861",
                    "cp862",
                    "cp863",
                    "cp864",
                    "cp865",
                    "cp866",
                    "CP868",
                    "cp869",
                    "CP870",
                    "CP871",
                    "cp880",
                    "cp891",
                    "cp903",
                    "cp904",
                    "CP905",
                    "CP918",
                    "CP936",
                    "csa7-1",
                    "csa7-2",
                    "csAdobeStandardEncoding",
                    "csASCII",
                    "CSA_T500-1983",
                    "CSA_Z243.4-1985-1",
                    "CSA_Z243.4-1985-2",
                    "CSA_Z243.4-1985-gr",
                    "csBig5",
                    "csBOCU-1",
                    "csCESU-8",
                    "csDECMCS",
                    "csDKUS",
                    "csEBCDICATDEA",
                    "csEBCDICCAFR",
                    "csEBCDICDKNO",
                    "csEBCDICDKNOA",
                    "csEBCDICES",
                    "csEBCDICESA",
                    "csEBCDICESS",
                    "csEBCDICFISE",
                    "csEBCDICFISEA",
                    "csEBCDICFR",
                    "csEBCDICIT",
                    "csEBCDICPT",
                    "csEBCDICUK",
                    "csEBCDICUS",
                    "csEUCFixWidJapanese",
                    "csEUCKR",
                    "csEUCPkdFmtJapanese",
                    "csGB2312",
                    "csHalfWidthKatakana",
                    "csHPDesktop",
                    "csHPLegal",
                    "csHPMath8",
                    "csHPPiFont",
                    "csHPPSMath",
                    "csHPRoman8",
                    "csIBBM904",
                    "csIBM037",
                    "csIBM038",
                    "csIBM1026",
                    "csIBM273",
                    "csIBM274",
                    "csIBM275",
                    "csIBM277",
                    "csIBM278",
                    "csIBM280",
                    "csIBM281",
                    "csIBM284",
                    "csIBM285",
                    "csIBM290",
                    "csIBM297",
                    "csIBM420",
                    "csIBM423",
                    "csIBM424",
                    "csIBM500",
                    "csIBM851",
                    "csIBM855",
                    "csIBM857",
                    "csIBM860",
                    "csIBM861",
                    "csIBM863",
                    "csIBM864",
                    "csIBM865",
                    "csIBM866",
                    "csIBM868",
                    "csIBM869",
                    "csIBM870",
                    "csIBM871",
                    "csIBM880",
                    "csIBM891",
                    "csIBM903",
                    "csIBM905",
                    "csIBM918",
                    "csIBMEBCDICATDE",
                    "csIBMSymbols",
                    "csIBMThai",
                    "csINVARIANT",
                    "csISO102T617bit",
                    "csISO10367Box",
                    "csISO103T618bit",
                    "csISO10646UTF1",
                    "csISO10Swedish",
                    "csISO111ECMACyrillic",
                    "csISO11SwedishForNames",
                    "csISO121Canadian1",
                    "csISO122Canadian2",
                    "csISO123CSAZ24341985gr",
                    "csISO128T101G2",
                    "csISO139CSN369103",
                    "csISO13JISC6220jp",
                    "csISO141JUSIB1002",
                    "csISO143IECP271",
                    "csISO146Serbian",
                    "csISO147Macedonian",
                    "csISO14JISC6220ro",
                    "csISO150",
                    "csISO150GreekCCITT",
                    "csISO151Cuba",
                    "csISO153GOST1976874",
                    "csISO158Lap",
                    "csISO159JISX02121990",
                    "csISO15Italian",
                    "csISO16Portuguese",
                    "csISO17Spanish",
                    "csISO18Greek7Old",
                    "csISO19LatinGreek",
                    "csISO2022JP",
                    "csISO2022JP2",
                    "csISO2022KR",
                    "csISO2033",
                    "csISO21German",
                    "csISO25French",
                    "csISO27LatinGreek1",
                    "csISO2IntlRefVersion",
                    "csISO42JISC62261978",
                    "csISO47BSViewdata",
                    "csISO49INIS",
                    "csISO4UnitedKingdom",
                    "csISO50INIS8",
                    "csISO51INISCyrillic",
                    "csISO5427Cyrillic",
                    "csISO5428Greek",
                    "csISO57GB1988",
                    "csISO58GB231280",
                    "csISO60DanishNorwegian",
                    "csISO60Norwegian1",
                    "csISO61Norwegian2",
                    "csISO646basic1983",
                    "csISO646Danish",
                    "csISO6937Add",
                    "csISO69French",
                    "csISO70VideotexSupp1",
                    "csISO84Portuguese2",
                    "csISO85Spanish2",
                    "csISO86Hungarian",
                    "csISO87JISX0208",
                    "csISO88596E",
                    "csISO88596I",
                    "csISO88598E",
                    "csISO88598I",
                    "csISO8859Supp",
                    "csISO88Greek7",
                    "csISO89ASMO449",
                    "csISO90",
                    "csISO91JISC62291984a",
                    "csISO92JISC62991984b",
                    "csISO93JIS62291984badd",
                    "csISO94JIS62291984hand",
                    "csISO95JIS62291984handadd",
                    "csISO96JISC62291984kana",
                    "csISO99NAPLPS",
                    "csISOLatin1",
                    "csISOLatin2",
                    "csISOLatin3",
                    "csISOLatin4",
                    "csISOLatin5",
                    "csISOLatin6",
                    "csISOLatinArabic",
                    "csISOLatinCyrillic",
                    "csISOLatinGreek",
                    "csISOLatinHebrew",
                    "csISOTextComm",
                    "csJISEncoding",
                    "csKOI8R",
                    "csKSC56011987",
                    "csKSC5636",
                    "csMacintosh",
                    "csMicrosoftPublishing",
                    "csMnem",
                    "csMnemonic",
                    "csNATSDANO",
                    "csNATSDANOADD",
                    "csNATSSEFI",
                    "csNATSSEFIADD",
                    "CSN_369103",
                    "csPC775Baltic",
                    "csPC850Multilingual",
                    "csPC862LatinHebrew",
                    "csPC8CodePage437",
                    "csPC8DanishNorwegian",
                    "csPC8Turkish",
                    "csPCp852",
                    "csPTCP154",
                    "csShiftJIS",
                    "csUCS4",
                    "csUnicode",
                    "csUnicode11",
                    "csUnicode11UTF7",
                    "csUnicodeASCII",
                    "csUnicodeIBM1261",
                    "csUnicodeIBM1264",
                    "csUnicodeIBM1265",
                    "csUnicodeIBM1268",
                    "csUnicodeIBM1276",
                    "csUnicodeLatin1",
                    "csUnknown8BiT",
                    "csUSDK",
                    "csVenturaInternational",
                    "csVenturaMath",
                    "csVenturaUS",
                    "csVIQR",
                    "csVISCII",
                    "csWindows30Latin1",
                    "csWindows31J",
                    "csWindows31Latin1",
                    "csWindows31Latin2",
                    "csWindows31Latin5",
                    "cuba",
                    "cyrillic",
                    "Cyrillic-Asian",
                    "de",
                    "dec",
                    "DEC-MCS",
                    "DIN_66003",
                    "dk",
                    "dk-us",
                    "DS2089",
                    "DS_2089",
                    "e13b",
                    "EBCDIC-AT-DE",
                    "EBCDIC-AT-DE-A",
                    "EBCDIC-BE",
                    "EBCDIC-BR",
                    "EBCDIC-CA-FR",
                    "ebcdic-cp-ar1",
                    "ebcdic-cp-ar2",
                    "ebcdic-cp-be",
                    "ebcdic-cp-ca",
                    "ebcdic-cp-ch",
                    "EBCDIC-CP-DK",
                    "ebcdic-cp-es",
                    "ebcdic-cp-fi",
                    "ebcdic-cp-fr",
                    "ebcdic-cp-gb",
                    "ebcdic-cp-gr",
                    "ebcdic-cp-he",
                    "ebcdic-cp-is",
                    "ebcdic-cp-it",
                    "ebcdic-cp-nl",
                    "EBCDIC-CP-NO",
                    "ebcdic-cp-roece",
                    "ebcdic-cp-se",
                    "ebcdic-cp-tr",
                    "ebcdic-cp-us",
                    "ebcdic-cp-wt",
                    "ebcdic-cp-yu",
                    "EBCDIC-Cyrillic",
                    "ebcdic-de-273+euro",
                    "ebcdic-dk-277+euro",
                    "EBCDIC-DK-NO",
                    "EBCDIC-DK-NO-A",
                    "EBCDIC-ES",
                    "ebcdic-es-284+euro",
                    "EBCDIC-ES-A",
                    "EBCDIC-ES-S",
                    "ebcdic-fi-278+euro",
                    "EBCDIC-FI-SE",
                    "EBCDIC-FI-SE-A",
                    "EBCDIC-FR",
                    "ebcdic-fr-297+euro",
                    "ebcdic-gb-285+euro",
                    "EBCDIC-INT",
                    "ebcdic-international-500+euro",
                    "ebcdic-is-871+euro",
                    "EBCDIC-IT",
                    "ebcdic-it-280+euro",
                    "EBCDIC-JP-E",
                    "EBCDIC-JP-kana",
                    "ebcdic-Latin9--euro",
                    "ebcdic-no-277+euro",
                    "EBCDIC-PT",
                    "ebcdic-se-278+euro",
                    "EBCDIC-UK",
                    "EBCDIC-US",
                    "ebcdic-us-37+euro",
                    "ECMA-114",
                    "ECMA-118",
                    "ECMA-cyrillic",
                    "ELOT_928",
                    "ES",
                    "ES2",
                    "EUC-JP",
                    "EUC-KR",
                    "Extended_UNIX_Code_Fixed_Width_for_Japanese",
                    "Extended_UNIX_Code_Packed_Format_for_Japanese",
                    "FI",
                    "fr",
                    "gb",
                    "GB18030",
                    "GB2312",
                    "GBK",
                    "GB_1988-80",
                    "GB_2312-80",
                    "GOST_19768-74",
                    "greek",
                    "greek-ccitt",
                    "greek7",
                    "greek7-old",
                    "greek8",
                    "hebrew",
                    "HP-DeskTop",
                    "HP-Legal",
                    "HP-Math8",
                    "HP-Pi-font",
                    "hp-roman8",
                    "hu",
                    "HZ-GB-2312",
                    "IBM-1047",
                    "IBM-Symbols",
                    "IBM-Thai",
                    "IBM00858",
                    "IBM00924",
                    "IBM01140",
                    "IBM01141",
                    "IBM01142",
                    "IBM01143",
                    "IBM01144",
                    "IBM01145",
                    "IBM01146",
                    "IBM01147",
                    "IBM01148",
                    "IBM01149",
                    "IBM037",
                    "IBM038",
                    "IBM1026",
                    "IBM1047",
                    "IBM273",
                    "IBM274",
                    "IBM275",
                    "IBM277",
                    "IBM278",
                    "IBM280",
                    "IBM281",
                    "IBM284",
                    "IBM285",
                    "IBM290",
                    "IBM297",
                    "IBM367",
                    "IBM420",
                    "IBM423",
                    "IBM424",
                    "IBM437",
                    "IBM500",
                    "IBM775",
                    "IBM819",
                    "IBM850",
                    "IBM851",
                    "IBM852",
                    "IBM855",
                    "IBM857",
                    "IBM860",
                    "IBM861",
                    "IBM862",
                    "IBM863",
                    "IBM864",
                    "IBM865",
                    "IBM866",
                    "IBM868",
                    "IBM869",
                    "IBM870",
                    "IBM871",
                    "IBM880",
                    "IBM891",
                    "IBM903",
                    "IBM904",
                    "IBM905",
                    "IBM918",
                    "IEC_P27-1",
                    "INIS",
                    "INIS-8",
                    "INIS-cyrillic",
                    "INVARIANT",
                    "irv",
                    "ISO-10646",
                    "ISO-10646-J-1",
                    "ISO-10646-UCS-2",
                    "ISO-10646-UCS-4",
                    "ISO-10646-UCS-Basic",
                    "ISO-10646-Unicode-Latin1",
                    "ISO-10646-UTF-1",
                    "ISO-2022-CN",
                    "ISO-2022-CN-EXT",
                    "ISO-2022-JP",
                    "ISO-2022-JP-2",
                    "ISO-2022-KR",
                    "ISO-8859-1",
                    "ISO-8859-1-Windows-3.0-Latin-1",
                    "ISO-8859-1-Windows-3.1-Latin-1",
                    "ISO-8859-10",
                    "ISO-8859-13",
                    "ISO-8859-14",
                    "ISO-8859-15",
                    "ISO-8859-16",
                    "ISO-8859-2",
                    "ISO-8859-2-Windows-Latin-2",
                    "ISO-8859-3",
                    "ISO-8859-4",
                    "ISO-8859-5",
                    "ISO-8859-6",
                    "ISO-8859-6-E",
                    "ISO-8859-6-I",
                    "ISO-8859-7",
                    "ISO-8859-8",
                    "ISO-8859-8-E",
                    "ISO-8859-8-I",
                    "ISO-8859-9",
                    "ISO-8859-9-Windows-Latin-5",
                    "iso-celtic",
                    "iso-ir-10",
                    "iso-ir-100",
                    "iso-ir-101",
                    "iso-ir-102",
                    "iso-ir-103",
                    "iso-ir-109",
                    "iso-ir-11",
                    "iso-ir-110",
                    "iso-ir-111",
                    "iso-ir-121",
                    "iso-ir-122",
                    "iso-ir-123",
                    "iso-ir-126",
                    "iso-ir-127",
                    "iso-ir-128",
                    "iso-ir-13",
                    "iso-ir-138",
                    "iso-ir-139",
                    "iso-ir-14",
                    "iso-ir-141",
                    "iso-ir-142",
                    "iso-ir-143",
                    "iso-ir-144",
                    "iso-ir-146",
                    "iso-ir-147",
                    "iso-ir-148",
                    "iso-ir-149",
                    "iso-ir-15",
                    "iso-ir-150",
                    "iso-ir-151",
                    "iso-ir-152",
                    "iso-ir-153",
                    "iso-ir-154",
                    "iso-ir-155",
                    "iso-ir-157",
                    "iso-ir-158",
                    "iso-ir-159",
                    "iso-ir-16",
                    "iso-ir-17",
                    "iso-ir-18",
                    "iso-ir-19",
                    "iso-ir-199",
                    "iso-ir-2",
                    "iso-ir-21",
                    "iso-ir-226",
                    "iso-ir-25",
                    "iso-ir-27",
                    "iso-ir-37",
                    "iso-ir-4",
                    "iso-ir-42",
                    "iso-ir-47",
                    "iso-ir-49",
                    "iso-ir-50",
                    "iso-ir-51",
                    "iso-ir-54",
                    "iso-ir-55",
                    "iso-ir-57",
                    "iso-ir-58",
                    "iso-ir-6",
                    "iso-ir-60",
                    "iso-ir-61",
                    "iso-ir-69",
                    "iso-ir-70",
                    "iso-ir-8-1",
                    "iso-ir-8-2",
                    "iso-ir-84",
                    "iso-ir-85",
                    "iso-ir-86",
                    "iso-ir-87",
                    "iso-ir-88",
                    "iso-ir-89",
                    "iso-ir-9-1",
                    "iso-ir-9-2",
                    "iso-ir-90",
                    "iso-ir-91",
                    "iso-ir-92",
                    "iso-ir-93",
                    "iso-ir-94",
                    "iso-ir-95",
                    "iso-ir-96",
                    "iso-ir-98",
                    "iso-ir-99",
                    "ISO-Unicode-IBM-1261",
                    "ISO-Unicode-IBM-1264",
                    "ISO-Unicode-IBM-1265",
                    "ISO-Unicode-IBM-1268",
                    "ISO-Unicode-IBM-1276",
                    "ISO5427Cyrillic1981",
                    "ISO646-CA",
                    "ISO646-CA2",
                    "ISO646-CN",
                    "ISO646-CU",
                    "ISO646-DE",
                    "ISO646-DK",
                    "ISO646-ES",
                    "ISO646-ES2",
                    "ISO646-FI",
                    "ISO646-FR",
                    "ISO646-FR1",
                    "ISO646-GB",
                    "ISO646-HU",
                    "ISO646-IT",
                    "ISO646-JP",
                    "ISO646-JP-OCR-B",
                    "ISO646-KR",
                    "ISO646-NO",
                    "ISO646-NO2",
                    "ISO646-PT",
                    "ISO646-PT2",
                    "ISO646-SE",
                    "ISO646-SE2",
                    "ISO646-US",
                    "ISO646-YU",
                    "ISO_10367-box",
                    "ISO_2033-1983",
                    "ISO_5427",
                    "ISO_5427:1981",
                    "ISO_5428:1980",
                    "ISO_646.basic:1983",
                    "ISO_646.irv:1983",
                    "ISO_646.irv:1991",
                    "ISO_6937-2-25",
                    "ISO_6937-2-add",
                    "ISO_8859-1",
                    "ISO_8859-10:1992",
                    "ISO_8859-14",
                    "ISO_8859-14:1998",
                    "ISO_8859-15",
                    "ISO_8859-16",
                    "ISO_8859-16:2001",
                    "ISO_8859-1:1987",
                    "ISO_8859-2",
                    "ISO_8859-2:1987",
                    "ISO_8859-3",
                    "ISO_8859-3:1988",
                    "ISO_8859-4",
                    "ISO_8859-4:1988",
                    "ISO_8859-5",
                    "ISO_8859-5:1988",
                    "ISO_8859-6",
                    "ISO_8859-6-E",
                    "ISO_8859-6-I",
                    "ISO_8859-6:1987",
                    "ISO_8859-7",
                    "ISO_8859-7:1987",
                    "ISO_8859-8",
                    "ISO_8859-8-E",
                    "ISO_8859-8-I",
                    "ISO_8859-8:1988",
                    "ISO_8859-9",
                    "ISO_8859-9:1989",
                    "ISO_8859-supp",
                    "ISO_9036",
                    "IT",
                    "JIS_C6220-1969",
                    "JIS_C6220-1969-jp",
                    "JIS_C6220-1969-ro",
                    "JIS_C6226-1978",
                    "JIS_C6226-1983",
                    "JIS_C6229-1984-a",
                    "JIS_C6229-1984-b",
                    "JIS_C6229-1984-b-add",
                    "JIS_C6229-1984-hand",
                    "JIS_C6229-1984-hand-add",
                    "JIS_C6229-1984-kana",
                    "JIS_Encoding",
                    "JIS_X0201",
                    "JIS_X0208-1983",
                    "JIS_X0212-1990",
                    "jp",
                    "jp-ocr-a",
                    "jp-ocr-b",
                    "jp-ocr-b-add",
                    "jp-ocr-hand",
                    "jp-ocr-hand-add",
                    "js",
                    "JUS_I.B1.002",
                    "JUS_I.B1.003-mac",
                    "JUS_I.B1.003-serb",
                    "katakana",
                    "KOI8-E",
                    "KOI8-R",
                    "KOI8-U",
                    "korean",
                    "KSC5636",
                    "KSC_5601",
                    "KS_C_5601-1987",
                    "KS_C_5601-1989",
                    "l1",
                    "l10",
                    "l2",
                    "l3",
                    "l4",
                    "l5",
                    "l6",
                    "l8",
                    "lap",
                    "Latin-9",
                    "latin-greek",
                    "Latin-greek-1",
                    "latin-lap",
                    "latin1",
                    "latin1-2-5",
                    "latin10",
                    "latin2",
                    "latin3",
                    "latin4",
                    "latin5",
                    "latin6",
                    "latin8",
                    "mac",
                    "macedonian",
                    "macintosh",
                    "Microsoft-Publishing",
                    "MNEM",
                    "MNEMONIC",
                    "MS936",
                    "MSZ_7795.3",
                    "MS_Kanji",
                    "NAPLPS",
                    "NATS-DANO",
                    "NATS-DANO-ADD",
                    "NATS-SEFI",
                    "NATS-SEFI-ADD",
                    "NC_NC00-10:81",
                    "NF_Z_62-010",
                    "NF_Z_62-010_(1973)",
                    "no",
                    "no2",
                    "NS_4551-1",
                    "NS_4551-2",
                    "PC-Multilingual-850+euro",
                    "PC8-Danish-Norwegian",
                    "PC8-Turkish",
                    "PT",
                    "PT154",
                    "PT2",
                    "PTCP154",
                    "r8",
                    "ref",
                    "roman8",
                    "SCSU",
                    "se",
                    "se2",
                    "SEN_850200_B",
                    "SEN_850200_C",
                    "serbian",
                    "Shift_JIS",
                    "ST_SEV_358-88",
                    "T.101-G2",
                    "T.61",
                    "T.61-7bit",
                    "T.61-8bit",
                    "TIS-620",
                    "uk",
                    "UNICODE-1-1",
                    "UNICODE-1-1-UTF-7",
                    "UNKNOWN-8BIT",
                    "us",
                    "US-ASCII",
                    "us-dk",
                    "UTF-16",
                    "UTF-16BE",
                    "UTF-16LE",
                    "UTF-32",
                    "UTF-32BE",
                    "UTF-32LE",
                    "UTF-7",
                    "UTF-8",
                    "Ventura-International",
                    "Ventura-Math",
                    "Ventura-US",
                    "videotex-suppl",
                    "VIQR",
                    "VISCII",
                    "windows-1250",
                    "windows-1251",
                    "windows-1252",
                    "windows-1253",
                    "windows-1254",
                    "windows-1255",
                    "windows-1256",
                    "windows-1257",
                    "windows-1258",
                    "Windows-31J",
                    "windows-936",
                    "X0201",
                    "x0201-7",
                    "x0208",
                    "x0212",
                    "yu"]
        
        for s in encodingString {
            if let enc = toStrEncodingToEncoding(from: s) {
                print("\(s) - \(enc) - \(enc.rawValue)")
            } else {
                print("\(s) - nil")
            }
            
        }
        print("NAMED_ENCODING_MAP: [String: UInt] = [")
        for s in encodingString {
            if let enc = toStrEncodingToEncoding(from: s) {
                print("\"\(s)\": \(enc.rawValue),")
            }
            
        }
        print("]")
    }
    
    private func toStrEncodingToEncoding(from string: String) -> String.Encoding? {
        let cfe = CFStringConvertIANACharSetNameToEncoding(string as CFString)
        if cfe == kCFStringEncodingInvalidId { return nil }
        let se = CFStringConvertEncodingToNSStringEncoding(cfe)
        return String.Encoding(rawValue: se)
    }
    #endif

    static var allTests: [(String, (WebRequestTests) -> () -> ())] = {
        var rtn: [(String, (WebRequestTests) -> () -> ())] = []
        rtn.append(("testSingleRequest", testSingleRequest))
        
        #if swift(>=5.5) && !_runtime(_ObjC)
        rtn.append(("testAsyncSingleRequest", testAsyncSingleRequest))
        #endif
        
        rtn.append(contentsOf: [
            ("testMultiRequest", testMultiRequest),
            ("testMultiRequestEventOnCompleted", testMultiRequestEventOnCompleted),
            ("testMultiRequestEventOnCompletedWithMaxConcurrentCount", testMultiRequestEventOnCompletedWithMaxConcurrentCount),
            ("testRepeatRequest", testRepeatRequest),
            ("testRepeatRequestCancelled", testRepeatRequestCancelled),
            ("testRepeatRequestUpdateURL", testRepeatRequestUpdateURL),
            ("testRepeatRequestUpdateURLCancelled", testRepeatRequestUpdateURLCancelled),
        ])
        
        #if swift(>=5.5) && !_runtime(_ObjC)
        rtn.append(("testAsyncRepeatRequest", testAsyncRepeatRequest))
        #endif
        
        rtn.append(contentsOf: [
            
            ("testDownloadFile", testDownloadFile),
            ("testUploadFile", testUploadFile),
            ("testStreamedEvents", testStreamedEvents),
            ("testDeinitHandler", testDeinitHandler)
        ])
        
        return rtn
    }()
}
