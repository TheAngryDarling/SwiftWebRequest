//
//  SyncLock.swift
//  
//
//  Created by Tyler Anger on 2022-11-14.
//

import Foundation

/// Class that synchronizing access to a resource using a shared lock
/// This means one lock can be used to control access to multiple resources
internal class SharedResourceLock<Resource, Lock>: NSLocking where Lock: NSLocking {
    private let _lock: Lock
    private var _resource: Resource
    
    public var value: Resource {
        get {
            return self.withUpdatingLock {
                return $0
            }
        }
        set {
            self.withUpdatingLock {
                $0 = newValue
            }
        }
    }
    
    /// Create a new shared resource lock
    /// - Parameters:
    ///   - resource: The resource to keep synchronized
    ///   - lock: The lock to use to keep the resource synchonized
    public init(resource: Resource,
                lock: Lock) {
        self._lock = lock
        self._resource = resource
    }
    /// Lock the resource
    public func lock() {
        self._lock.lock()
    }
    /// Unlock the resource
    public func unlock() {
        self._lock.unlock()
    }
    
    /// Lock the resource for the duration of the block call
    public func withLock<T>(for block: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try block()
    }
    
    /// Lock the resource for the duration of the block allowing the block to access/update the resource
    public func withUpdatingLock<T>(for block: (inout Resource) throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try block(&self._resource)
    }
}

#if swift(>=5.5)
extension SharedResourceLock: @unchecked Sendable where Resource: Sendable { }
#endif

extension SharedResourceLock: CustomStringConvertible {
    public var description: String { return "\(self._resource)" }
}

/// Class that synchronizing access to a resource using a lock
internal class ResourceLock<Resource>: SharedResourceLock<Resource, NSLock> {
    /// Dependant locks of this resource
    /// These locks should be locked before locking the local lock and access the resource
    private let _dependantLocks: [NSLocking]
    
    /// Create a new resource lock
    /// - Parameters:
    ///   - resource: The resource to keep synchronized
    ///   - dependantLocks: Any additional dependant locks to be accessed befor alowing access to ther resource
    public init(resource: Resource,
                dependantLocks: [NSLocking] = []) {
        self._dependantLocks = dependantLocks
        super.init(resource: resource, lock: NSLock())
    }
    
    public override func lock() {
        for d in self._dependantLocks {
            d.lock()
        }
        super.lock()
    }
    public override func unlock() {
        for d in self._dependantLocks {
            d.unlock()
        }
        super.unlock()
    }
    
}

internal extension SharedResourceLock where Resource: ExpressibleByNilLiteral {
    convenience init(lock: Lock) {
        self.init(resource: Resource(nilLiteral: ()), lock: lock)
    }
}

internal extension ResourceLock where Resource: ExpressibleByNilLiteral {
    convenience init(dependantLocks: [NSLocking] = []) {
        self.init(resource: Resource(nilLiteral: ()),
                  dependantLocks: dependantLocks)
    }
}


internal extension SharedResourceLock where Resource == Bool {
    /// Returns value of state while changing value to inverted state
    func valueThenInvert() -> Bool {
        return self.withUpdatingLock { r in
            let rtn = r
            r = !r
            return rtn
        }
    }
    /// Returns inverted value of state while changing value to inverted state
    func invertThenValue() -> Bool {
        return self.withUpdatingLock { r in
            let rtn = !r
            r = rtn
            return rtn
        }
    }
    /// Returns value of state while changing value to provided value
    func valueThenSet(to newValue: Resource) -> Bool {
        return self.withUpdatingLock { r in
            let rtn = r
            r = newValue
            return rtn
        }
    }
    
}
