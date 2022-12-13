# WebRequest
![swift >= 4.0](https://img.shields.io/badge/swift-%3E%3D4.0-brightgreen.svg)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)

Simple classes for creating single, multiple, and repeated data web requests as well as upload and download requests
Each class provides event handlers for start, resume, suspend, cancel, complete
Each class supports Notification events for start, resume, suspend, cancel, complete 

Classes DataRequest, DownloadRequest, and UploadRequest provider access to delegate event handlers 

## Usage

Data Web Request
```Swift
let session = URLSession(configuration: URLSessionConfiguration.default)
let request = WebRequest.DataRequest(URL(string: "http://.....")!, usingSession: session) { r in 
 // completion handler here
}

//Setup secondary event handlers
request.requestStarted = { r in 

}
request.requestResumed = { r in 

}
request.requestSuspended = { r in 

}
request.requestCancelled = { r in 

}
//This is an additional completion handler that gets called as well as the completionHandler in the constructor
request.requestCompleted = { r in 

}
request.requestStateChanged = { r, s in 

}
request.resume() //Starts the request
request.waitUntilComplete() //Lets wait until all requests have completed.  No guarentee that all event handlers have been called when we release
```

Parallel Web Requests:
```Swift
let session = URLSession(configuration: URLSessionConfiguration.default)
var requestURLs: [URL] = []
for _ in 0..<10 {
    requestURLs.append(URL(string: "http://.....")!)
}
let request = WebRequest.GroupRequest(requestURLs, maxConcurrentRequests: = 5) { rA in 
// completion handler here
}

//Setup secondary event handlers
request.requestStarted = { r in 

}
request.requestResumed = { r in 

}
request.requestSuspended = { r in 

}
request.requestCancelled = { r in 

}
//This is an additional completion handler that gets called as well as the completionHandler in the constructor
request.requestCompleted = { r in 

}
request.requestStateChanged = { r, s in 

}

//Setup secondary child event handlers
request.singleRequestStarted = { gR, i, r in 

}
request.singleRequestResumed = { gR, i, r in 

}
request.singleRequestSuspended = { gR, i, r in 

}
request.singleRequestCancelled = { gR, i, r in 

}
//This is an additional completion handler that gets called as well as the completionHandler in the constructor
request.singleRequestCompleted = { gR, i, r in 

}
request.singleRequestStateChanged = { gR, i, r, s in 

}


request.resume() //Starts the request
request.waitUntilComplete() //Lets wait until all requests have completed.  No guarentee that all event handlers have been called when we release
```

Repeat Data Web Request
```Swift

func repeatHandler(_ request: WebRequest.RepeatedRequest<Void>, _ results: WebRequest.SingleRequest.Results, _ repeatCount: Int) -> WebRequest.RepeatedRequest<Void>.RepeatResults {

    print("[\(repeatCount)] - \(results.originalURL!) - Finished")
    if repeatCount < 5 { return WebRequest.RepeatedRequest<Void>.RepeatResults.repeat }
    else { return WebRequest.RepeatedRequest<Void>.RepeatResults.results(nil) } //Allows us to parse results here and send them to the completion handler.  That way they request data is only being parsed once.
}


let session = URLSession(configuration: URLSessionConfiguration.default)
let request = WebRequest.RepeatedRequest<Void>(URL(string: "http://.....")!, usingSession: session, repeatHandler: repeatHandler) { rs, r, e in
// completion handler here
}

//Setup secondary event handlers
request.requestStarted = { r in 

}
request.requestResumed = { r in 

}
request.requestSuspended = { r in 

}
request.requestCancelled = { r in 

}
//This is an additional completion handler that gets called as well as the completionHandler in the constructor
request.requestCompleted = { r in 

}
request.requestStateChanged = { r, s in 

}
request.resume() //Starts the request
request.waitUntilComplete() //Lets wait until all requests have completed.  No guarentee that all event handlers have been called when we release
```

Download Web Request

Note: due to compatibility issues with OpenSwift < 4.1.4 session.downloadTask not working 
A workaround is put in place by using the session.dataTask that mimics the process.
```Swift
let session = URLSession(configuration: URLSessionConfiguration.default)
let request = WebRequest.DownloadRequest(URL(string: "http://.....")!, usingSession: session) { r in 
 // completion handler here
 guard let downloadLocation = r.location else {
    ///error
 }
 /// process file
 /// File may be deleted after event handler
}

//Setup secondary event handlers
request.requestStarted = { r in 

}
request.requestResumed = { r in 

}
request.requestSuspended = { r in 

}
request.requestCancelled = { r in 

}
//This is an additional completion handler that gets called as well as the completionHandler in the constructor
request.requestCompleted = { r in 

}
request.requestStateChanged = { r, s in 

}
request.resume() //Starts the request
request.waitUntilComplete() //Lets wait until all requests have completed.  No guarentee that all event handlers have been called when we release
```

Upload Web Request
```Swift
let session = URLSession(configuration: URLSessionConfiguration.default)
let uploadFile: URL = ...
let request = WebRequest.UploadRequest(URL(string: "http://.....")!, 
                                       fromFile: uploadFile, 
                                       usingSession: session) { r in 
 // completion handler here
 
}

//Setup secondary event handlers
request.requestStarted = { r in 

}
request.requestResumed = { r in 

}
request.requestSuspended = { r in 

}
request.requestCancelled = { r in 

}
//This is an additional completion handler that gets called as well as the completionHandler in the constructor
request.requestCompleted = { r in 

}
request.requestStateChanged = { r, s in 

}
request.resume() //Starts the request
request.waitUntilComplete() //Lets wait until all requests have completed.  No guarentee that all event handlers have been called when we release
```

## Dependencies
* [LittleWebServer](https://github.com/TheAngryDarling/SwiftLittleWebServer.git) - Used in the **Test Cases** as a local server to test request cases and generate testable responses

## Author

* **Tyler Anger** - *Initial work* - [TheAngryDarling](https://github.com/TheAngryDarling)

## License

This project is licensed under Apache License v2.0 - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

This package is based off the work done by Adam Sharp [here](https://gist.github.com/sharplet/37210c02aa9e525b55f823bb67712725)
