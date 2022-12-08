//
//  TaskedWebRequest+async.swift
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
