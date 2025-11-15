# MyRec Testing Quick Guide

## Essential Imports

```swift
import XCTest
@testable import MyRec
#if canImport(MyRecCore)
@testable import MyRecCore
#endif
```

## Test Template

```swift
final class FeatureTests: XCTestCase {
    var sut: SystemUnderTest!

    override func setUp() {
        super.setUp()
        sut = SystemUnderTest()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testFeature() {
        // Arrange
        let input = "test"

        // Act
        let result = sut.process(input)

        // Assert
        XCTAssertEqual(result, "expected")
    }
}
```

## Common Patterns

### Notifications
```swift
func testNotification() {
    let expectation = expectation(description: "Notification")

    let observer = NotificationCenter.default.addObserver(
        forName: .myNotification, object: nil, queue: .main
    ) { _ in expectation.fulfill() }

    NotificationCenter.default.post(name: .myNotification, object: nil)
    wait(for: [expectation], timeout: 1.0)

    NotificationCenter.default.removeObserver(observer)
}
```

### State Machines
```swift
func testStateTransition() {
    var state = RecordingState.idle
    XCTAssertTrue(state.isIdle)

    state = .recording(startTime: Date())
    XCTAssertTrue(state.isRecording)
}
```

### CGRect Validation
```swift
func testRegionBounds() {
    let viewModel = RegionSelectionViewModel(
        screenBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )

    viewModel.selectedRegion = CGRect(x: 1900, y: 1000, width: 500, height: 500)

    XCTAssertLessThanOrEqual(viewModel.selectedRegion!.maxX, 1920)
}
```

## Quick Fixes

### "No such module 'MyRecCore'"
```swift
#if canImport(MyRecCore)
import MyRecCore
#endif
```

### "Type not found in scope"
1. Add to `Package.swift` sources
2. Make type `public`
3. Import with `#if canImport(MyRecCore)`

### "inaccessible due to 'private'"
```swift
// Change from:
private func method() { }

// To:
func method() { }  // Internal by default
```

### UI Component Crashes (NSStatusItem, NSWindow)
```swift
// ❌ Don't create UI in tests
let controller = StatusBarController()  // Crashes

// ✅ Test logic without UI
NotificationCenter.default.post(name: .startRecording, object: nil)
```

## Running Tests

```bash
# Swift Package Manager (recommended)
swift test
swift test --filter StatusBarControllerTests

# Xcode
⌘U
```

## Key Rules

**✅ DO:**
- Test ViewModels, Services, Models
- Test one thing per test
- Use Arrange-Act-Assert
- Clean up in `tearDown()`

**❌ DON'T:**
- Create UI components (NSWindow, NSStatusItem)
- Test private methods
- Use `sleep()` - use expectations
- Test implementation details

## Quick Checklist

When tests fail:
- [ ] Module imported with `#if canImport(MyRecCore)`?
- [ ] Type marked `public` in MyRecCore?
- [ ] File in Package.swift sources?
- [ ] Trying to create UI? (Don't!)
- [ ] Using expectations for async?

## Common Assertions

```swift
XCTAssertEqual(a, b)
XCTAssertTrue(condition)
XCTAssertNil(value)
XCTAssertGreaterThan(a, b)
```

---

**Last Updated:** Week 2, Day 6
