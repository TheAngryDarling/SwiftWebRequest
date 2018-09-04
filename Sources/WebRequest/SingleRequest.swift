//
//  SingleWebRequest.swift
//  WebRequest
//
//  Created by Tyler Anger on 2018-06-06.
//

import Foundation


extension WebRequest {
    
    // Used for response.textEncodingName to String.Encoding
    fileprivate struct StringEncoding {
        #if os(macOS) && os(iOS) && os(tvOS) && os(watchOS)
        public static func encodingNameToStringEncoding(_ name: String) -> String.Encoding? {
            let cfe = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            if cfe == kCFStringEncodingInvalidId { return nil }
            let se = CFStringConvertEncodingToNSStringEncoding(cfe)
            return String.Encoding(rawValue: se)
        }
        #else
        public static let NAMED_ENCODING_MAP: [String: UInt] = [
            "437": 2147484672,
            "850": 2147484688,
            "851": 2147484689,
            "852": 2147484690,
            "855": 2147484691,
            "857": 2147484692,
            "860": 2147484693,
            "861": 2147484694,
            "862": 2147484695,
            "863": 2147484696,
            "865": 2147484698,
            "866": 2147484699,
            "869": 2147484700,
            "Adobe-Symbol-Encoding": 6,
            "ANSI_X3.4-1968": 1,
            "ANSI_X3.4-1986": 1,
            "arabic": 2147483652,
            "ASCII": 1,
            "ASMO-708": 2147484166,
            "Big5": 2147486211,
            "Big5-HKSCS": 2147486214,
            "chinese": 2147486000,
            "cp-gr": 2147484700,
            "cp-is": 2147484694,
            "cp037": 2147486722,
            "cp367": 1,
            "cp437": 2147484672,
            "cp775": 2147484678,
            "CP819": 5,
            "cp850": 2147484688,
            "cp851": 2147484689,
            "cp852": 2147484690,
            "cp855": 2147484691,
            "cp857": 2147484692,
            "cp860": 2147484693,
            "cp861": 2147484694,
            "cp862": 2147484695,
            "cp863": 2147484696,
            "cp864": 2147484697,
            "cp865": 2147484698,
            "cp866": 2147484699,
            "cp869": 2147484700,
            "CP936": 2147484705,
            "csASCII": 1,
            "csBig5": 2147484707,
            "csEUCKR": 2147486016,
            "csEUCPkdFmtJapanese": 3,
            "csGB2312": 2147486000,
            "csHalfWidthKatakana": 2147485216,
            "csIBM037": 2147486722,
            "csIBM855": 2147484691,
            "csIBM857": 2147484692,
            "csIBM860": 2147484693,
            "csIBM861": 2147484694,
            "csIBM863": 2147484696,
            "csIBM864": 2147484697,
            "csIBM865": 2147484698,
            "csIBM866": 2147484699,
            "csIBM869": 2147484700,
            "csISO159JISX02121990": 2147485219,
            "csISO2022JP": 21,
            "csISO2022JP2": 2147485729,
            "csISO2022KR": 2147485760,
            "csISO42JISC62261978": 2147485220,
            "csISO58GB231280": 2147486000,
            "csISO87JISX0208": 2147485218,
            "csISO88596E": 2147484166,
            "csISO88596I": 2147484166,
            "csISO88598E": 2147484168,
            "csISO88598I": 2147484168,
            "csISOLatin1": 5,
            "csISOLatin2": 9,
            "csISOLatin3": 2147484163,
            "csISOLatin4": 2147484164,
            "csISOLatin5": 2147484169,
            "csISOLatin6": 2147484170,
            "csISOLatinArabic": 2147484166,
            "csISOLatinCyrillic": 2147484165,
            "csISOLatinGreek": 2147484167,
            "csISOLatinHebrew": 2147484168,
            "csJISEncoding": 2147485730,
            "csKOI8R": 2147486210,
            "csKSC56011987": 2147484706,
            "csMacintosh": 30,
            "csPC775Baltic": 2147484678,
            "csPC850Multilingual": 2147484688,
            "csPC862LatinHebrew": 2147484695,
            "csPC8CodePage437": 2147484672,
            "csPCp852": 2147484690,
            "csShiftJIS": 8,
            "csUCS4": 2348810496,
            "csUnicode": 10,
            "csUnicode11": 10,
            "csUnicode11UTF7": 2214592768,
            "csVISCII": 2147486215,
            "csWindows31J": 8,
            "csWindows31Latin1": 12,
            "csWindows31Latin2": 15,
            "csWindows31Latin5": 14,
            "cyrillic": 2147483655,
            "ebcdic-cp-ca": 2147486722,
            "ebcdic-cp-nl": 2147486722,
            "ebcdic-cp-us": 2147486722,
            "ebcdic-cp-wt": 2147486722,
            "ECMA-114": 2147484166,
            "ECMA-118": 2147484167,
            "ELOT_928": 2147484167,
            "EUC-JP": 3,
            "EUC-KR": 2147486016,
            "Extended_UNIX_Code_Packed_Format_for_Japanese": 3,
            "GB18030": 2147485234,
            "GB2312": 2147486000,
            "GBK": 2147485233,
            "GB_2312-80": 2147486000,
            "greek": 2147483654,
            "greek8": 2147484167,
            "hebrew": 2147483653,
            "HZ-GB-2312": 2147486213,
            "IBM037": 2147486722,
            "IBM367": 1,
            "IBM437": 2147484672,
            "IBM775": 2147484678,
            "IBM819": 5,
            "IBM850": 2147484688,
            "IBM851": 2147484689,
            "IBM852": 2147484690,
            "IBM855": 2147484691,
            "IBM857": 2147484692,
            "IBM860": 2147484693,
            "IBM861": 2147484694,
            "IBM862": 2147484695,
            "IBM863": 2147484696,
            "IBM864": 2147484697,
            "IBM865": 2147484698,
            "IBM866": 2147484699,
            "IBM869": 2147484700,
            "ISO-10646-UCS-2": 10,
            "ISO-10646-UCS-4": 2348810496,
            "ISO-2022-CN": 2147485744,
            "ISO-2022-CN-EXT": 2147485745,
            "ISO-2022-JP": 21,
            "ISO-2022-JP-2": 2147485729,
            "ISO-2022-KR": 2147485760,
            "ISO-8859-1": 5,
            "ISO-8859-1-Windows-3.0-Latin-1": 5,
            "ISO-8859-1-Windows-3.1-Latin-1": 5,
            "ISO-8859-10": 2147484170,
            "ISO-8859-13": 2147484173,
            "ISO-8859-14": 2147484174,
            "ISO-8859-15": 2147484175,
            "ISO-8859-16": 2147484176,
            "ISO-8859-2": 9,
            "ISO-8859-2-Windows-Latin-2": 9,
            "ISO-8859-3": 2147484163,
            "ISO-8859-4": 2147484164,
            "ISO-8859-5": 2147484165,
            "ISO-8859-6": 2147484166,
            "ISO-8859-6-E": 2147484166,
            "ISO-8859-6-I": 2147484166,
            "ISO-8859-7": 2147484167,
            "ISO-8859-8": 2147484168,
            "ISO-8859-8-E": 2147484168,
            "ISO-8859-8-I": 2147484168,
            "ISO-8859-9": 2147484169,
            "ISO-8859-9-Windows-Latin-5": 2147484169,
            "iso-ir-100": 5,
            "iso-ir-101": 9,
            "iso-ir-109": 2147484163,
            "iso-ir-110": 2147484164,
            "iso-ir-126": 2147484167,
            "iso-ir-127": 2147484166,
            "iso-ir-138": 2147484168,
            "iso-ir-144": 2147484165,
            "iso-ir-148": 2147484169,
            "iso-ir-149": 2147484706,
            "iso-ir-157": 2147484170,
            "iso-ir-159": 2147485219,
            "iso-ir-226": 2147484176,
            "iso-ir-42": 2147485220,
            "iso-ir-58": 2147486000,
            "iso-ir-6": 1,
            "ISO646-US": 1,
            "ISO_646.irv:1983": 1,
            "ISO_646.irv:1991": 1,
            "ISO_8859-1": 5,
            "ISO_8859-10:1992": 2147484170,
            "ISO_8859-15": 2147484175,
            "ISO_8859-16": 2147484176,
            "ISO_8859-16:2001": 2147484176,
            "ISO_8859-1:1987": 5,
            "ISO_8859-2": 9,
            "ISO_8859-2:1987": 9,
            "ISO_8859-3": 2147484163,
            "ISO_8859-3:1988": 2147484163,
            "ISO_8859-4": 2147484164,
            "ISO_8859-4:1988": 2147484164,
            "ISO_8859-5": 2147484165,
            "ISO_8859-5:1988": 2147484165,
            "ISO_8859-6": 2147484166,
            "ISO_8859-6-E": 2147484166,
            "ISO_8859-6-I": 2147484166,
            "ISO_8859-6:1987": 2147484166,
            "ISO_8859-7": 2147484167,
            "ISO_8859-7:1987": 2147484167,
            "ISO_8859-8": 2147484168,
            "ISO_8859-8-E": 2147484168,
            "ISO_8859-8-I": 2147484168,
            "ISO_8859-8:1988": 2147484168,
            "ISO_8859-9": 2147484169,
            "ISO_8859-9:1989": 2147484169,
            "JIS_C6226-1978": 2147485220,
            "JIS_C6226-1983": 2147485218,
            "JIS_Encoding": 2147485730,
            "JIS_X0201": 2147485216,
            "JIS_X0208-1983": 2147485218,
            "JIS_X0212-1990": 2147485219,
            "KOI8-R": 2147486210,
            "KOI8-U": 2147486216,
            "korean": 2147483651,
            "KSC_5601": 2147484706,
            "KS_C_5601-1987": 2147484706,
            "KS_C_5601-1989": 2147484706,
            "l1": 5,
            "l10": 2147484176,
            "l2": 9,
            "l3": 2147484163,
            "l4": 2147484164,
            "l5": 2147484169,
            "l6": 2147484170,
            "Latin-9": 2147484175,
            "latin1": 5,
            "latin10": 2147484176,
            "latin2": 9,
            "latin3": 2147484163,
            "latin4": 2147484164,
            "latin5": 2147484169,
            "latin6": 2147484170,
            "mac": 30,
            "macintosh": 30,
            "MS936": 2147484705,
            "MS_Kanji": 8,
            "Shift_JIS": 2147486209,
            "TIS-620": 2147484701,
            "UNICODE-1-1": 10,
            "UNICODE-1-1-UTF-7": 2214592768,
            "us": 1,
            "US-ASCII": 1,
            "UTF-16": 10,
            "UTF-16BE": 2415919360,
            "UTF-16LE": 2483028224,
            "UTF-32": 2348810496,
            "UTF-32BE": 2550137088,
            "UTF-32LE": 2617245952,
            "UTF-7": 2214592768,
            "UTF-8": 4,
            "VISCII": 2147486215,
            "windows-1250": 15,
            "windows-1251": 11,
            "windows-1252": 12,
            "windows-1253": 13,
            "windows-1254": 14,
            "windows-1255": 2147484933,
            "windows-1256": 2147484934,
            "windows-1257": 2147484935,
            "windows-1258": 2147484936,
            "Windows-31J": 8,
            "windows-936": 2147484705,
            "X0201": 2147485216,
            "x0208": 2147485218,
            "x0212": 2147485219,
            ]
        
        public static func encodingNameToStringEncoding(_ name: String) -> String.Encoding? {
            guard let rawValue = NAMED_ENCODING_MAP[name] else { return nil }
            return String.Encoding(rawValue: rawValue)
        }
        
        #endif
        
        
    }
    
}

public extension WebRequest {
    /*
     Allows for a single web request
    */
    public class SingleRequest: WebRequest {
        
        
        
        //Results container for request response
        public struct Results {
            public let request: URLRequest
            public let response: URLResponse?
            public let error: Error?
            public private(set) var data: Data?
            
            // The original url of the request
            public var originalURL: URL? { return request.url }
            // The url from the response.   This could differ from the originalURL if there were redirects
            public var currentURL: URL? {
                if let r = response?.url { return r }
                else { return originalURL }
            }
            
            internal var hasResponse: Bool {
                return (self.response != nil || self.error != nil || self.data != nil)
            }
            
            // Trys to convert the resposne data to a string using the response.textEncodingName if provided.  If not it will use the defaultEncoding that is passed into the method
            public func responseString(defaultEncoding encoding: String.Encoding = .utf8) -> String? {
                guard let response = self.response else { return nil }
                guard let data = self.data else { return nil }
                guard let textEncodingName = response.textEncodingName else { return nil }
                
                let encoding = StringEncoding.encodingNameToStringEncoding(textEncodingName) ?? encoding
                //let rtn = String(data: data, encoding: encoding)
                //return rtn
                return String(data: data, encoding: encoding)
            }
            
            public init(request: URLRequest, response: URLResponse? = nil, error: Error? = nil, data: Data? = nil) {
                self.request = request
                self.response = response
                self.error = error
                self.data = data
            }
            
            // Allows for clearing of the reponse data.  This can be handy when working with GroupRequests with a lot of data.  That way you can process each request as it comes in and clear the data so its not sitting in memeory until all requests are finished
            internal mutating func emptyData() {
                self.data?.removeAll()
                self.data = nil
            }
            
        }
        
        
        private var task: URLSessionDataTask
        
        // Results from the request
        public private(set) var results: Results
        private var completionHandler: ((Results) -> Void)? = nil
        
        public override var state: WebRequest.State {
            //Some times completion handler gets called even though task state says its still running on linux
            guard self.results.hasResponse else {
                return WebRequest.State(rawValue: self.task.state.rawValue)!
            }
            
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            if let e = self.results.error as NSError?, e.code == NSURLErrorCancelled {
                return WebRequest.State.canceling
            } else {
                return WebRequest.State.completed
            }
            #else
            if let e = self.results.error as? NSError, e.code == NSURLErrorCancelled {
                return WebRequest.State.canceling
            } else {
                return WebRequest.State.completed
            }
            #endif
            
        }
        
        // The URL request object currently being handled by the request.
        public var currentRequest: URLRequest? { return self.task.currentRequest }
        // The original request object passed when the request was created.
        public private(set) var originalRequest: URLRequest?
        // The server’s response to the currently active request.
        public var response: URLResponse? { return self.task.response }
        
        // An app-provided description of the current request.
        public var webDescription: String? {
            get { return self.task.taskDescription }
            set { self.task.taskDescription = newValue }
        }
        // An identifier uniquely identifies the task within a given session.
        public var taskIdentifier: Int { return self.task.taskIdentifier }
        
        public override var error: Swift.Error? { return self.task.error }
        
        // The relative priority at which you’d like a host to handle the task, specified as a floating point value between 0.0 (lowest priority) and 1.0 (highest priority).
        public var priority: Float {
            get { return self.task.priority }
            set { self.task.priority = newValue }
        }
        
        #if os(macOS) && os(iOS) && os(tvOS) && os(watchOS)
        // A representation of the overall request progress
        @available (macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
        public override var progress: Progress { return self.task.progress }
        #endif
         // Create a new WebRequest using the provided url and session.
        public init(_ request: URLRequest, usingSession session: URLSession) {
            self.originalRequest = request
            self.task = URLSessionDataTask()
            self.results = Results(request: request)
            super.init()
            self.task = session.dataTask(with: request) { data, response, error in
                
                self.results = Results(request: request, response: response, error: error, data: data)

                // Must do this otherwise things might just hang in limbo
                self.triggerStateChange(.completed)
                
                if let handler = self.completionHandler {
                    self.callAsyncEventHandler { handler(self.results) }
                }
                
            }
        }
        
         // Create a new WebRequest using the provided url and session
        public convenience init(_ url: URL, usingSession session: URLSession) {
            self.init(URLRequest(url: url), usingSession: session)
        }
        
         // Create a new WebRequest using the provided requset and session. and call the completionHandler when finished
        public convenience init(_ request: URLRequest, usingSession session: URLSession, completionHandler: @escaping (Results) -> Void) {
            self.init(request, usingSession: session)
            self.completionHandler = completionHandler
        }
        
        // Create a new WebRequest using the provided url and session. and call the completionHandler when finished
        public convenience init(_ url: URL, usingSession session: URLSession, completionHandler: @escaping (Results) -> Void) {
            self.init(URLRequest(url: url), usingSession: session, completionHandler: completionHandler)
        }
        
        // Resumes the request, if it is suspended.
        public override func resume() {
            super.resume()
            self.task.resume()
        }
        
        // Temporarily suspends a request.
        public override func suspend() {
            super.suspend()
            self.task.suspend()
        }
        
        // Cancels the request
        public override func cancel() {
            
            //Setup results for cancelled requests
            if !self.results.hasResponse {
                self.results = Results(request: self.originalRequest!,
                                       response: nil,
                                       error: SingleRequest.createCancelationError(forURL: self.originalRequest!.url!),
                                       data: nil)
            }
            
            super.cancel()
            self.task.cancel()
            
        }
        
        // Allows for clearing of the reponse data.  This can be handy when working with GroupRequests with a lot of data.  That way you can process each request as it comes in and clear the data so its not sitting in memeory until all requests are finished
        public func emptyResultsData() {
            self.results.emptyData()
        }
        
        
        internal static func createCancelationError(forURL url: URL) -> Error {
            #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            var uInfo: [String: Any] = [:]
            uInfo[NSURLErrorFailingURLStringErrorKey] = "\(url)"
            uInfo[NSURLErrorFailingURLErrorKey] = url
            uInfo[NSLocalizedDescriptionKey] = "cancelled"
            return  NSError(domain: "NSURLErrorDomain", code: NSURLErrorCancelled, userInfo: uInfo)
            #else
            return URLError(_nsError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil))
            #endif
        }
    }
}
