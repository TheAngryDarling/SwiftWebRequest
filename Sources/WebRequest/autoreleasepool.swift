//
//  autoreleasepool.swift
//  WebRequest
//
//  Created by Tyler Anger on 2021-02-10.
//

import Foundation

#if !_runtime(_ObjC) && (!swift(>=4.2) || swift(>=5.0.3))
public func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
    return try body()
}
#endif
