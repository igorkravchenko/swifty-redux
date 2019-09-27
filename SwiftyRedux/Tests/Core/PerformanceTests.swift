import XCTest
@testable import SwiftyRedux

private struct AnyAction: Action {}

class PerformanceTests: XCTestCase {
    typealias State = Int

    var observers: [(State) -> Void]!
    var store: Store<State, Action>!

    override func setUp() {
        super.setUp()

        observers = (0..<3000).map { _ in { _ in } }
        store = Store<State, Action>(state: 0, reducer: { _, _ in })
    }

    func testNotify() {
        self.observers.forEach { self.store.subscribe(observer: $0) }
        self.measure {
            self.store.dispatchAndWait(AnyAction())
        }
    }

    func testSubscribe() {
        self.measure {
            self.observers.forEach { self.store.subscribe(observer: $0) }
        }
    }
}
