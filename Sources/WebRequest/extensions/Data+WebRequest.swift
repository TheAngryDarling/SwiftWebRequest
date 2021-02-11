//
//  Data+WebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-02-09.
//

import Foundation

extension Data: TaskedWebRequestResultsContainer {
    public mutating func emptyLocallyLoadedData() {
        self.removeAll(keepingCapacity: false)
    }
}
