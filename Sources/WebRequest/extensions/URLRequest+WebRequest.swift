//
//  URLRequest+WebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-01-02.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif

internal extension URLRequest {
    
    enum HTTPMethod: Equatable {
        case get
        case head
        case post
        case put
        case delete
        case connect
        case options
        case trace
        case patch
        case other(String)
        
        public static let knownMethods: [HTTPMethod] = [
            .get,
            .head,
            .post,
            .put,
            .delete,
            .connect,
            .options,
            .trace,
            .patch,
        ]
        
        public var rawValue: String {
            switch self {
                case .get: return "GET"
                case .head: return "HEAD"
                case .post: return "POST"
                case .put: return "PUT"
                case .delete: return "DELETE"
                case .connect: return "CONNECT"
                case .options: return "OPTIONS"
                case .trace: return "TRACE"
                case .patch: return "PATCH"
                case .other(let rtn): return rtn.uppercased()
            }
        }
        
        public init(rawValue: String) {
            precondition(!rawValue.isEmpty, "HTTP Method can not be empty string")
            let uValue = rawValue.uppercased()
            guard let m = HTTPMethod.knownMethods.first(where: { return $0.rawValue == uValue }) else {
                self = .other(uValue)
                return
            }
            self = m
        }
        
        public static func ==(lhs: HTTPMethod, rhs: HTTPMethod) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
    }
    
    var _httpMethod: HTTPMethod? {
        get {
            guard let rtn = self.httpMethod, !rtn.isEmpty else {
                return nil
            }
            return HTTPMethod(rawValue: rtn)
        }
        set {
            self.httpMethod = newValue?.rawValue
        }
    }
    
    /// Create new URLRequest copying old request details
    init(url: URL,
         _ oldRequest: URLRequest) {
        self = oldRequest
        self.url = url
    }
}
