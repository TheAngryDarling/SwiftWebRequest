//
//  Array+WebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2019-06-16.
//

import Foundation

internal extension Array {
    
    #if !swift(>=4.1.4)
        /// Removes all the elements that satisfy the given predicate.
        ///
        /// Use this method to remove every element in a collection that meets
        /// particular criteria. This example removes all the odd values from an
        /// array of numbers:
        ///
        ///     var numbers = [5, 6, 7, 8, 9, 10, 11]
        ///     numbers.removeAll(where: { $0 % 2 == 1 })
        ///     // numbers == [6, 8, 10]
        ///
        /// - Parameter predicate: A closure that takes an element of the
        ///   sequence as its argument and returns a Boolean value indicating
        ///   whether the element should be removed from the collection.
        ///
        /// - Complexity: O(*n*), where *n* is the length of the collection.
        mutating func removeAll(where predicate: (Element) throws -> Bool) rethrows {
            var idx: Int = 0
            while idx < self.endIndex {
                if try predicate(self[idx]) { self.remove(at: idx) }
                else { idx += 1 }
            }
        }
        
    #endif
    #if !swift(>=4.0.4)
    /// Returns an array containing the non-`nil` results of calling the given
    /// transformation with each element of this sequence.
    ///
    /// Use this method to receive an array of nonoptional values when your
    /// transformation produces an optional value.
    ///
    /// In this example, note the difference in the result of using `map` and
    /// `compactMap` with a transformation that returns an optional `Int` value.
    ///
    ///     let possibleNumbers = ["1", "2", "three", "///4///", "5"]
    ///
    ///     let mapped: [Int?] = possibleNumbers.map { str in Int(str) }
    ///     // [1, 2, nil, nil, 5]
    ///
    ///     let compactMapped: [Int] = possibleNumbers.compactMap { str in Int(str) }
    ///     // [1, 2, 5]
    ///
    /// - Parameter transform: A closure that accepts an element of this
    ///   sequence as its argument and returns an optional value.
    /// - Returns: An array of the non-`nil` results of calling `transform`
    ///   with each element of the sequence.
    ///
    /// - Complexity: O(*m* + *n*), where *n* is the length of this sequence
    ///   and *m* is the length of the result.
    func compactMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
        var rtn: [ElementOfResult] = []
        for element in self {
            if let nE = try transform(element) { rtn.append(nE) }
        }
        return rtn
    }
    #endif
    #if !swift(>=4.2)
    func allSatisfy(_ predicate: (Element) throws -> Bool) rethrows -> Bool {
        for element in self {
            if !(try predicate(element)) { return false }
        }
        return true
    }
    #endif
}
internal extension Array where Element: Equatable {
    #if !swift(>=5.0)
    func firstIndex(of element: Element) -> Index? {
        for (index, e) in self.enumerated() {
            if e == element { return index }
        }
        return nil
    }
    #endif
}
