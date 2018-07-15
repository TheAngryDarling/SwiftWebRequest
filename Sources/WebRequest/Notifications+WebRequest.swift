//
//  Notifications+WebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2018-06-08.
//

import Foundation

public extension Notification.Name {
    public struct WebRequest {
        
        public struct Keys {
            public static let State = "org.webrequest.notification.key.state"
            public static let ChildRequest = "org.webrequest.notification.key.child"
            public static let ChildIndex = "org.webrequest.notification.key.child.index"
            
        }
        
        /// Posted when a `URLSessionTask` is starting. The notification `object` contains the resumed `URLSessionTask`.
        public static let DidStart = Notification.Name(rawValue: "org.webrequest.notification.name.didStart")
        
        /// Posted when a `URLSessionTask` is resumed. The notification `object` contains the resumed `URLSessionTask`.
        public static let DidResume = Notification.Name(rawValue: "org.webrequest.notification.name.didResume")
        
        /// Posted when a `URLSessionTask` is suspended. The notification `object` contains the suspended `URLSessionTask`.
        public static let DidSuspend = Notification.Name(rawValue: "org.webrequest.notification.name.didSuspend")
        
        /// Posted when a `URLSessionTask` is cancelled. The notification `object` contains the cancelled `URLSessionTask`.
        public static let DidCancel = Notification.Name(rawValue: "org.webrequest.notification.name.didCancel")
        
        /// Posted when a `URLSessionTask` is completed. The notification `object` contains the completed `URLSessionTask`.
        public static let DidComplete = Notification.Name(rawValue: "org.webrequest.notification.name.didComplete")
        
        /// Posted when a `URLSessionTask` is completed. The notification `object` contains the completed `URLSessionTask`.
        public static let StateChanged = Notification.Name(rawValue: "org.webrequest.notification.name.stateChanged")
        
        
        /// Posted when a child `URLSessionTask` is starting. The notification `object` contains the resumed `URLSessionTask`.
        public static let DidStartChild = Notification.Name(rawValue: "org.webrequest.notification.name.didStartChild")
        
        /// Posted when a child `URLSessionTask` is resumed. The notification `object` contains the resumed `URLSessionTask`.
        public static let DidResumeChild = Notification.Name(rawValue: "org.webrequest.notification.name.didResumeChild")
        
        /// Posted when a child `URLSessionTask` is suspended. The notification `object` contains the suspended `URLSessionTask`.
        public static let DidSuspendChild = Notification.Name(rawValue: "org.webrequest.notification.name.didSuspendChild")
        
        /// Posted when a child `URLSessionTask` is cancelled. The notification `object` contains the cancelled `URLSessionTask`.
        public static let DidCancelChild = Notification.Name(rawValue: "org.webrequest.notification.name.didCancelChild")
        
        /// Posted when a child `URLSessionTask` is completed. The notification `object` contains the completed `URLSessionTask`.
        public static let DidCompleteChild = Notification.Name(rawValue: "org.webrequest.notification.name.didCompleteChild")
        
        /// Posted when a child `URLSessionTask` is completed. The notification `object` contains the completed `URLSessionTask`.
        public static let StateChangedChild = Notification.Name(rawValue: "org.webrequest.notification.name.stateChangedChild")
        
        
        /// Posted when a repeat `URLSessionTask` is starting. The notification `object` contains the resumed `URLSessionTask`.
        public static let DidStartRepeat = Notification.Name(rawValue: "org.webrequest.notification.name.didStartRepeat")
        
        /// Posted when a repeat `URLSessionTask` is resumed. The notification `object` contains the resumed `URLSessionTask`.
        public static let DidResumeRepeat = Notification.Name(rawValue: "org.webrequest.notification.name.didResumeRepeat")
        
        /// Posted when a repeat `URLSessionTask` is suspended. The notification `object` contains the suspended `URLSessionTask`.
        public static let DidSuspendRepeat = Notification.Name(rawValue: "org.webrequest.notification.name.didSuspendRepeat")
        
        /// Posted when a repeat `URLSessionTask` is cancelled. The notification `object` contains the cancelled `URLSessionTask`.
        public static let DidCancelRepeat = Notification.Name(rawValue: "org.webrequest.notification.name.didCancelRepeat")
        
        /// Posted when a repeat `URLSessionTask` is completed. The notification `object` contains the completed `URLSessionTask`.
        public static let DidCompleteRepeat = Notification.Name(rawValue: "org.webrequest.notification.name.didCompleteRepeat")
        
        /// Posted when a repeat `URLSessionTask` is completed. The notification `object` contains the completed `URLSessionTask`.
        public static let StateChangedRepeat = Notification.Name(rawValue: "org.webrequest.notification.name.stateChangedRepeat")
    }
    
    
}
