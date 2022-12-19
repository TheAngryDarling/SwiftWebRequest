//
//  WebRequestSharedSessionDelegate.swift
//
//
//  Created by Tyler Anger on 2022-11-14.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif
/// A Shared URL Session Delegate where multiple child delegates can be added
/// to monitor events on the same session
/// This delegate is designed to allow WebRequests share the same URLSession
/// and not have to copy it
public class WebRequestSharedSessionDelegate: NSObject {
    private let childDelegateLock = NSLock()
    private var _childDelegates: [(id: String, delegate: URLSessionDelegate)] = []
    
    private var childDelegates: [(id: String, delegate: URLSessionDelegate)] {
        self.childDelegateLock.lock()
        defer { self.childDelegateLock.unlock() }
        return self._childDelegates
    }
    deinit {
        self.childDelegateLock.lock()
        defer { self.childDelegateLock.unlock() }
        
        self._childDelegates.removeAll()
    }
    
    /// Add a URL Session Delegate to the end proxy list
    /// - Parameters:
    ///   - uid: The unique id associated with the delegate
    ///   - delegate: The delegate to add
    /// - Returns: Returns the unique id associated with the delegate
    @discardableResult
    public func appendChildDelegate(withId uid: String,
                                    delegate: URLSessionDelegate) -> String {
        self.childDelegateLock.lock()
        defer { self.childDelegateLock.unlock() }
        
        precondition(!self._childDelegates.contains(where: { return $0.id == uid }),
                     "Id already in use")
        self._childDelegates.append((id: uid, delegate: delegate))
        return uid
    }
    
    /// Add a URL Session Delegate to the end proxy list
    /// - Parameters:
    ///   - delegate: The delegate to add
    /// - Returns: Returns the unique id associated with the delegate
    @discardableResult
    public func appendChildDelegate(delegate: URLSessionDelegate) -> String {
        return self.appendChildDelegate(withId: UUID().uuidString, delegate: delegate)
    }
    
    /// Inserts a URL Session Delegate to the beginning proxy list
    /// - Parameters:
    ///   - uid: The unique id associated with the delegate
    ///   - delegate: The delegate to add
    /// - Returns: Returns the unique id associated with the delegate
    @discardableResult
    public func pushChildDelegate(withId uid: String,
                                  delegate: URLSessionDelegate) -> String {
        self.childDelegateLock.lock()
        defer { self.childDelegateLock.unlock() }
        
        precondition(!self._childDelegates.contains(where: { return $0.id == uid }),
                     "Id already in use")
        self._childDelegates.insert((id: uid, delegate: delegate), at: 0)
        return uid
    }
    
    /// Inserts a URL Session Delegate to the beginning proxy list
    /// - Parameters:
    ///   - delegate: The delegate to add
    /// - Returns: Returns the unique id associated with the delegate
    @discardableResult
    public func pushChildDelegate(delegate: URLSessionDelegate) -> String {
        return self.appendChildDelegate(withId: UUID().uuidString, delegate: delegate)
    }
    
    /// Remove a URL Session delegate from the proxy list
    /// - Parameter uid: The unique id associated with the delegate to remove
    public func removeChildDelegate(withId uid: String) {
        self.childDelegateLock.lock()
        defer { self.childDelegateLock.unlock() }
        
        self._childDelegates.removeAll(where: { return $0.id == uid })
    }
}

// MARK: - URLSessionDelegate
extension WebRequestSharedSessionDelegate: URLSessionDelegate {
    
    public func urlSession(_ session: URLSession,
                           didBecomeInvalidWithError error: Error?) {
        for (_, delegate) in self.childDelegates {
            #if _runtime(_ObjC)
            delegate.urlSession?(session, didBecomeInvalidWithError: error)
            #else
            delegate.urlSession(session, didBecomeInvalidWithError: error)
            #endif
        }
    }
    
    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                         URLCredential?) -> Void) {
        var hasExecutedCompletionHandler: Bool = false
        func wrappedCompletionHandler(_ ac: URLSession.AuthChallengeDisposition,
                                      _ c: URLCredential?) -> Void {
            #if _runtime(_ObjC)
            hasExecutedCompletionHandler = true
            completionHandler(ac, c)
            #else
            // There is no default callback.  if this is called we
            // assume it was intended
            hasExecutedCompletionHandler = true
            completionHandler(ac, c)
            #endif
        }
        for (_, delegate) in self.childDelegates {
            guard !hasExecutedCompletionHandler else {
                break
            }
            #if _runtime(_ObjC)
            delegate.urlSession?(session,
                                 didReceive: challenge,
                                 completionHandler: wrappedCompletionHandler)
            #else
            delegate.urlSession(session,
                                 didReceive: challenge,
                                 completionHandler: wrappedCompletionHandler)
            #endif
        }
        /*
        // there is no default callback
        if !hasExecutedCompletionHandler {
            completionHandler(.performDefaultHandling, nil)
        }
        */
    }
    
    
    #if _runtime(_ObjC) && swift(>=5.3)
    @available(macOS 11.0, iOS 7.0, tvOS 9.0, watchOS 2.0, *)
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        for (_, delegate) in self.childDelegates {
            //#if _runtime(_ObjC)
            delegate.urlSessionDidFinishEvents?(forBackgroundURLSession: session)
            //#else
            //delegate.urlSessionDidFinishEvents(forBackgroundURLSession: session)
            //#endif
        }
    }
    #endif
    
}
// MARK: - URLSessionTaskDelegate
extension WebRequestSharedSessionDelegate: URLSessionTaskDelegate {
    
    #if swift(>=4.1)
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public func urlSession(_ session: URLSession,
                             task: URLSessionTask,
                             willBeginDelayedRequest request: URLRequest,
                             completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        
        var hasExecutedCompletionHandler: Bool = false
        func wrappedCompletionHandler(_ drc: URLSession.DelayedRequestDisposition,
                                      _ r: URLRequest?) -> Void {
            #if _runtime(_ObjC)
            hasExecutedCompletionHandler = true
            completionHandler(drc, r)
            #else
            // if drc == .continueLoading then we can assume
            // the default callback was called
            if drc != .continueLoading {
                hasExecutedCompletionHandler = true
                completionHandler(drc, r)
            }
            #endif
        }
        
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionTaskDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                task: task,
                                willBeginDelayedRequest: request,
                                completionHandler: wrappedCompletionHandler)
                #else
                del.urlSession(session,
                                task: task,
                                willBeginDelayedRequest: request,
                                completionHandler: wrappedCompletionHandler)
                #endif
            }
        }
        
        
        // there is no default callback
        if !hasExecutedCompletionHandler {
            completionHandler(.continueLoading, nil)
        }
        
    }
    #endif

    #if _runtime(_ObjC)
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public func urlSession(_ session: URLSession,
                        taskIsWaitingForConnectivity task: URLSessionTask) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionTaskDelegate {
                //#if _runtime(_ObjC)
                del.urlSession?(session,
                                taskIsWaitingForConnectivity: task)
                /*#else
                del.urlSession(session,
                                taskIsWaitingForConnectivity: task)
                #endif*/
            }
        }
    }
    #endif
    
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void) {
        var hasExecutedCompletionHandler: Bool = false
        func wrappedCompletionHandler(_ rq: URLRequest?) -> Void {
            #if _runtime(_ObjC)
            hasExecutedCompletionHandler = true
            completionHandler(rq)
            #else
            // we ignore the default handler
            // and see if there is a custom one
            if rq != request {
                hasExecutedCompletionHandler = true
                completionHandler(rq)
            }
            #endif
        }
        
        for (_, delegate) in self.childDelegates {
            guard !hasExecutedCompletionHandler else {
                break
            }
            if let del = delegate as? URLSessionTaskDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                               task: task,
                               willPerformHTTPRedirection: response,
                               newRequest: request,
                               completionHandler: wrappedCompletionHandler)
                #else
                del.urlSession(session,
                               task: task,
                               willPerformHTTPRedirection: response,
                               newRequest: request,
                               completionHandler: wrappedCompletionHandler)
                #endif
            }
        }
        if !hasExecutedCompletionHandler {
            completionHandler(request)
        }
    }

    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                         URLCredential?) -> Void) {
        
        var hasExecutedCompletionHandler: Bool = false
        func wrappedCompletionHandler(_ ac: URLSession.AuthChallengeDisposition,
                                      _ c: URLCredential?) -> Void {
            #if _runtime(_ObjC)
            hasExecutedCompletionHandler = true
            completionHandler(ac, c)
            #else
            // we ignore the default handler
            if !(ac == .performDefaultHandling && c == nil) {
                hasExecutedCompletionHandler = true
                completionHandler(ac, c)
            }
            #endif
        }
        
        for (_, delegate) in self.childDelegates {
            guard !hasExecutedCompletionHandler else {
                break
            }
            if let del = delegate as? URLSessionTaskDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                               task: task,
                               didReceive: challenge,
                               completionHandler: wrappedCompletionHandler)
                #else
                del.urlSession(session,
                               task: task,
                               didReceive: challenge,
                               completionHandler: wrappedCompletionHandler)
                #endif
            }
        }
        if !hasExecutedCompletionHandler {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        var hasExecutedCompletionHandler: Bool = false
        func wrappedCompletionHandler(_ imp: InputStream?) -> Void {
            #if _runtime(_ObjC)
            hasExecutedCompletionHandler = true
            completionHandler(imp)
            #else
            // Ignore the default handler
            if imp != nil {
                hasExecutedCompletionHandler = true
                completionHandler(imp)
            }
            #endif
        }
        
        for (_, delegate) in self.childDelegates {
            guard !hasExecutedCompletionHandler else {
                break
            }
            if let del = delegate as? URLSessionTaskDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                               task: task,
                               needNewBodyStream: wrappedCompletionHandler)
                #else
                del.urlSession(session,
                               task: task,
                               needNewBodyStream: wrappedCompletionHandler)
                #endif
            }
        }
        
        if !hasExecutedCompletionHandler {
            completionHandler(nil)
        }
    }
    
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didSendBodyData bytesSent: Int64,
                           totalBytesSent: Int64,
                           totalBytesExpectedToSend: Int64) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionTaskDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                               task: task,
                               didSendBodyData: bytesSent,
                               totalBytesSent: totalBytesSent,
                               totalBytesExpectedToSend: totalBytesExpectedToSend)
                #else
                del.urlSession(session,
                               task: task,
                               didSendBodyData: bytesSent,
                               totalBytesSent: totalBytesSent,
                               totalBytesExpectedToSend: totalBytesExpectedToSend)
                #endif
            }
        }
    }

    #if _runtime(_ObjC)
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didFinishCollecting metrics: URLSessionTaskMetrics) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionTaskDelegate {
                //#if _runtime(_ObjC)
                del.urlSession?(session,
                               task: task,
                               didFinishCollecting: metrics)
                /*#else
                del.urlSession(session,
                               task: task,
                               didFinishCollecting: metrics)
                #endif*/
            }
        }
    }
    #endif
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionTaskDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                               task: task,
                               didCompleteWithError: error)
                #else
                del.urlSession(session,
                               task: task,
                               didCompleteWithError: error)
                #endif
            }
        }
    }
}
// MARK: - URLSessionDataDelegate
extension WebRequestSharedSessionDelegate: URLSessionDataDelegate {

    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        var hasExecutedCompletionHandler: Bool = false
        func wrappedCompletionHandler(_ rd: URLSession.ResponseDisposition) -> Void {
            #if _runtime(_ObjC)
            hasExecutedCompletionHandler = true
            completionHandler(rd)
            #else
            // There is no default callback
            // so if this gets executed it was for
            // a reason
            if rd != .allow {
                hasExecutedCompletionHandler = true
                completionHandler(rd)
            }
            #endif
        }
        for (_, delegate) in self.childDelegates {
            guard !hasExecutedCompletionHandler else {
                break
            }
            if let del = delegate as? URLSessionDataDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                dataTask: dataTask,
                                didReceive: response,
                                completionHandler: wrappedCompletionHandler)
                #else
                del.urlSession(session,
                                dataTask: dataTask,
                                didReceive: response,
                                completionHandler: wrappedCompletionHandler)
                #endif
            }
        }
        
         // no need for this as there is no
         // default callback
         if !hasExecutedCompletionHandler {
            completionHandler(.allow)
        }
    }
    
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didBecome downloadTask: URLSessionDownloadTask) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionDataDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                dataTask: dataTask,
                                didBecome: downloadTask)
                #else
                del.urlSession(session,
                                dataTask: dataTask,
                                didBecome: downloadTask)
                #endif
            }
        }
    }

    #if _runtime(_ObjC)
    @available(macOS 10.11, iOS 9.0, tvOS 9.0, watchOS 2.0, *)
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didBecome streamTask: URLSessionStreamTask) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionDataDelegate {
                //#if _runtime(_ObjC)
                del.urlSession?(session,
                                dataTask: dataTask,
                                didBecome: streamTask)
                /*#else
                del.urlSession(session,
                                dataTask: dataTask,
                                didBecome: streamTask)
                #endif*/
            }
        }
    }
    #endif
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive data: Data) {
        WebRequest.autoreleasepool {
            var data = data
            for (_, delegate) in self.childDelegates {
                if let del = delegate as? URLSessionDataDelegate {
                    
                    #if _runtime(_ObjC)
                    del.urlSession?(session,
                                    dataTask: dataTask,
                                    didReceive: data)
                    #else
                    del.urlSession(session,
                                    dataTask: dataTask,
                                    didReceive: data)
                    #endif
                    
                }
            }
        }
        
    }
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           willCacheResponse proposedResponse: CachedURLResponse,
                           completionHandler: @escaping (CachedURLResponse?) -> Void) {
        var hasExecutedCompletionHandler: Bool = false
        func wrappedCompletionHandler(_ cur: CachedURLResponse?) -> Void {
            #if _runtime(_ObjC)
            hasExecutedCompletionHandler = true
            completionHandler(cur)
            #else
            if cur != proposedResponse {
                hasExecutedCompletionHandler = true
                completionHandler(cur)
            }
            #endif
        }
        for (_, delegate) in self.childDelegates {
            guard !hasExecutedCompletionHandler else {
                break
            }
            if let del = delegate as? URLSessionDataDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                dataTask: dataTask,
                                willCacheResponse: proposedResponse,
                                completionHandler: wrappedCompletionHandler)
                #else
                del.urlSession(session,
                                dataTask: dataTask,
                                willCacheResponse: proposedResponse,
                                completionHandler: wrappedCompletionHandler)
                #endif
            }
        }
        
        if !hasExecutedCompletionHandler {
            completionHandler(proposedResponse)
        }
    }
    
}

// MARK: - URLSessionDownloadDelegate
extension WebRequestSharedSessionDelegate: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionDownloadDelegate {
                del.urlSession(session,
                               downloadTask: downloadTask,
                               didFinishDownloadingTo: location)
            }
        }
    }
    
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionDownloadDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                downloadTask: downloadTask,
                                didWriteData: bytesWritten,
                                totalBytesWritten: totalBytesWritten,
                                totalBytesExpectedToWrite: totalBytesExpectedToWrite)
                #else
                del.urlSession(session,
                                downloadTask: downloadTask,
                                didWriteData: bytesWritten,
                                totalBytesWritten: totalBytesWritten,
                                totalBytesExpectedToWrite: totalBytesExpectedToWrite)
                #endif
            }
        }
    }
    
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didResumeAtOffset fileOffset: Int64,
                           expectedTotalBytes: Int64) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionDownloadDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                downloadTask: downloadTask,
                                didResumeAtOffset: fileOffset,
                                expectedTotalBytes: expectedTotalBytes)
                #else
                del.urlSession(session,
                                downloadTask: downloadTask,
                                didResumeAtOffset: fileOffset,
                                expectedTotalBytes: expectedTotalBytes)
                #endif
            }
        }
        
    }
}


// MARK: - URLSessionStreamDelegate
#if swift(>=4.0) && !swift(>=5.2)
@available(macOS 10.11, iOS 9.0, tvOS 9.0, watchOS 2.0, *)
extension WebRequestSharedSessionDelegate: URLSessionStreamDelegate {
    public func urlSession(_ session: URLSession,
                           readClosedFor streamTask: URLSessionStreamTask) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionStreamDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                readClosedFor: streamTask)
                #else
                del.urlSession(session,
                                readClosedFor: streamTask)
                #endif
            }
        }
    }

    
    public func urlSession(_ session: URLSession,
                           writeClosedFor streamTask: URLSessionStreamTask) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionStreamDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                writeClosedFor: streamTask)
                #else
                del.urlSession(session,
                                writeClosedFor: streamTask)
                #endif
            }
        }
    }

    
    public func urlSession(_ session: URLSession,
                           betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionStreamDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                betterRouteDiscoveredFor: streamTask)
                #else
                del.urlSession(session,
                                betterRouteDiscoveredFor: streamTask)
                #endif
            }
        }
    }

    
    public func urlSession(_ session: URLSession,
                            streamTask: URLSessionStreamTask,
                            didBecome inputStream: InputStream,
                            outputStream: OutputStream) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionStreamDelegate {
                #if _runtime(_ObjC)
                del.urlSession?(session,
                                streamTask: streamTask,
                                didBecome: inputStream,
                                outputStream: outputStream)
                #else
                del.urlSession(session,
                                streamTask: streamTask,
                                didBecome: inputStream,
                                outputStream: outputStream)
                #endif
            }
        }
    }
}
#endif

// MARK: - URLSessionWebSocketDelegate
#if _runtime(_ObjC) && swift(>=5.4)
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension WebRequestSharedSessionDelegate: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didOpenWithProtocol proto: String?) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionWebSocketDelegate {
                //#if _runtime(_ObjC)
                del.urlSession?(session,
                                webSocketTask: webSocketTask,
                                didOpenWithProtocol: proto)
                /*#else
                del.urlSession(session,
                                webSocketTask: webSocketTask,
                                didOpenWithProtocol: proto)
                #endif*/
            }
        }
        
    }
    public func urlSession(_ session: URLSession,
                           webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                           reason: Data?) {
        for (_, delegate) in self.childDelegates {
            if let del = delegate as? URLSessionWebSocketDelegate {
                //#if _runtime(_ObjC)
                del.urlSession?(session,
                                webSocketTask: webSocketTask,
                                didCloseWith: closeCode,
                                reason: reason)
                /*#else
                del.urlSession(session,
                                webSocketTask: webSocketTask,
                                didCloseWith: closeCode,
                                reason: reason)
                #endif*/
            }
        }
        
    }
}
#endif

