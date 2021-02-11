//
//  URL+WebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-02-09.
//

import Foundation
#if swift(>=4.1)
    #if canImport(FoundationXML)
        import FoundationNetworking
    #endif
#endif

extension URL: TaskedWebRequestResultsContainer {
    public mutating func emptyLocallyLoadedData() {
        // Do nothing
    }
}
