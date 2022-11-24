//
//  CallableHandler.swift
//  
//
//  Created by Tyler Anger on 2022-11-22.
//

import Foundation

/// Structure containting a callable handler and flag indicating if the
/// handler was called
internal struct CallableHandler<Handler> {
    /// Indicator if the handler was called
    public var hasCalled: Bool
    /// The handler to call
    public var handler: Handler?
    
    init(_ handler: Handler?) {
        self.hasCalled = false
        self.handler = handler
    }
}

/// Resource lock specifically for CallableHandler objects
internal class HandlerResourceLock<Handler>: ResourceLock<CallableHandler<Handler>> {
    /// Indicator if the handler was called
    internal var hasCalled: Bool {
        get {
            return self.withUpdatingLock { return $0.hasCalled }
        }
    }
    
    internal init(_ handler: Handler?) {
        super.init(resource: .init(handler))
    }
}
