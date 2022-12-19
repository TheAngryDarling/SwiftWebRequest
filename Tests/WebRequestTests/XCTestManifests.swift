import XCTest

//#if !os(macOS)
#if !_runtime(_ObjC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(WebRequestTests.allTests),
    ]
}
#endif
