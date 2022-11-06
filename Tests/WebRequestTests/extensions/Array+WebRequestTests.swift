//
//  Array+WebRequestTests.swift
//  WebRequestTests
//
//  Created by Tyler Anger on 2021-08-05.
//

import Foundation

#if !swift(>=4.2)
extension Array {
    func firstIndex(where predicate: (Element) throws -> Bool) rethrows -> Index? {
        for (index, element) in self.enumerated() {
            if try predicate(element) { return index }
        }
        return nil
    }
}
#endif

internal extension Array {
    func first<T>(as type: T.Type) -> T? {
        for element in self {
            if let r = element as? T {
                return r
            }
        }
        return nil
    }
}
