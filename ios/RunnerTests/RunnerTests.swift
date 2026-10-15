import Flutter
import UIKit
import WebKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  @MainActor
  func testSopKeyboardAccessoryIsHiddenOnlyOnItsOwnWebView() {
    let sop = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
    let other = WKWebView(frame: sop.frame)
    func textInput(in view: UIView) -> UIView? {
      if view is UITextInput { return view }
      return view.subviews.compactMap { textInput(in: $0) }.first
    }
    guard let sopInput = textInput(in: sop), let otherInput = textInput(in: other) else {
      XCTFail("WKWebView must expose a text input responder")
      return
    }
    let originalClass = NSStringFromClass(type(of: otherInput))
    XCTAssertTrue(TrainingSopWebViewBridge.hideKeyboardAccessory(in: sop))
    XCTAssertNil(sopInput.inputAccessoryView)
    XCTAssertTrue(NSStringFromClass(type(of: sopInput)).hasPrefix("KaizenSopKeyboard_"))
    XCTAssertEqual(NSStringFromClass(type(of: otherInput)), originalClass)
    XCTAssertTrue(TrainingSopWebViewBridge.hideKeyboardAccessory(in: sop), "Repeated setup stays safe")
    XCTAssertEqual(sopInput.inputAssistantItem.leadingBarButtonGroups.count, 0)
    XCTAssertEqual(sopInput.inputAssistantItem.trailingBarButtonGroups.count, 0)
  }

}
