//
//  RepeatedDataRequest+async.swift
//  
//
//  Created by Tyler Anger on 2022-12-07.
//

import Foundation

#if swift(>=4.1)
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
#endif

#if swift(>=5.5)
@available(macOS 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension WebRequest.RepeatedDataRequest {
    func safeExecute() async -> Results {
        return await withCheckedContinuation({
            (continuation: CheckedContinuation<Results, Never>) in
            self.resume()
            self.waitUntilComplete()
            
            continuation.resume(returning: self.results)
        })
    }
    
    func execute() async throws -> (T?, URLRequest, URLResponse) {
        return try await withCheckedThrowingContinuation({
            (continuation: CheckedContinuation<(T?, URLRequest, URLResponse), Error>) in
            self.resume()
            self.waitUntilComplete()
            
            let r = self.results
            if let e = r.error {
                continuation.resume(throwing: e)
            } else {
                continuation.resume(returning: (r.object, r.request, r.response!))
            }
        })
    }
}
#endif

