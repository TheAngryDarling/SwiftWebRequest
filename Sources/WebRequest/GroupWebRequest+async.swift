//
//  GroupWebRequest+async.swift
//
//
//  Created by Tyler Anger on 2023-12-03.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
#endif

#if swift(>=5.5)
@available(macOS 10.15.0, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension WebRequest.StrictGroupRequest {
    /*
    func safeExecute() async -> [Request] {
        return await withCheckedContinuation({
            (continuation: CheckedContinuation<[Request], Never>) in
            self.resume()
            self.waitUntilComplete()
            
            continuation.resume(returning: self.requests)
        })
    }
    
    func execute() async throws -> [Request] {
        return try await withCheckedThrowingContinuation({
            (continuation: CheckedContinuation<[Request], Swift.Error>) in
            self.resume()
            self.waitUntilComplete()
            if let e = self.error {
                continuation.resume(throwing: e)
            } else {
                continuation.resume(returning: self.requests)
            }
        })
    }
    */
    func execute() async -> [Request] {
        return await withCheckedContinuation({
            (continuation: CheckedContinuation<[Request], Never>) in
            self.resume()
            self.waitUntilComplete()
            
            continuation.resume(returning: self.requests)
        })
    }
}
#endif
