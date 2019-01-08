import XCTest
@testable import SwiftyRedux

private typealias State = Int
private typealias StringAction = String

class StoreTests: XCTestCase {
    private var initialState: State!
    private var nopAction: StringAction = ""
    private var nopReducer: Reducer<State>!
    private var nopMiddleware: Middleware<State>!

    override func setUp() {
        super.setUp()

        initialState = 0
        nopAction = "action"
        nopReducer = { action, state in state }
        nopMiddleware = createMiddleware(sideEffect: { getState, dispatch in return { action in } })
    }

    func testMiddlewareIsExecutedOnlyOnceBeforeActionReceived() {
        var result = 0
        let middleware: Middleware<State> = createMiddleware { getState, dispatch, next in
            result += 1
            return { action in next(action) }
        }
        let store = Store(state: initialState, reducer: nopReducer, middleware: [middleware])

        store.dispatch("first")
        store.dispatch("second")
        store.dispatch("third")

        XCTAssertEqual(result, 1)
    }

    func testSideEffectMiddlewareIsExecutedOnlyOnceBeforeActionReceived() {
        var result = 0
        let middleware: Middleware<State> = createMiddleware { getState, dispatch in
            result += 1
            return { action in }
        }
        let store = Store(state: initialState, reducer: nopReducer, middleware: [middleware])

        store.dispatch("first")
        store.dispatch("second")
        store.dispatch("third")

        XCTAssertEqual(result, 1)
    }

    func testMiddlewareExecutesActionBodyAsManyTimesAsActionsReceived() {
        var result = 0
        let middleware: Middleware<State> = createMiddleware { getState, dispatch, next in
            return { action in
                result += 1
                next(action)
            }
        }
        let store = Store(state: initialState, reducer: nopReducer, middleware: [middleware])

        store.dispatch("first")
        store.dispatch("second")
        store.dispatch("third")

        XCTAssertEqual(result, 3)
    }

    func testSideffectMiddlewareExecutesActionBodyAsManyTimesAsActionsReceived() {
        var result = 0
        let middleware: Middleware<State> = createMiddleware { getState, dispatch in
            return { action in result += 1 }
        }
        let store = Store(state: initialState, reducer: nopReducer, middleware: [middleware])

        store.dispatch("first")
        store.dispatch("second")
        store.dispatch("third")

        XCTAssertEqual(result, 3)
    }

    func testStore_afterSubscribeAndDispatchFlow_deinits_andAllDisposablesDispose() {
        weak var store: Store<State>?
        var disposable: Disposable!

        autoreleasepool {
            let deinitStore = Store(state: initialState, reducer: nopReducer, middleware: [nopMiddleware])
            store = deinitStore
            disposable = deinitStore.subscribe(observer: { state in })
            deinitStore.dispatch("action")
        }

        XCTAssertTrue(disposable.isDisposed)
        XCTAssertNil(store)
    }

    func testMiddleware_whenRunOnDefaultQueue_isExecutedSequentiallyWithReducer() {
        var result = ""
        let middleware: Middleware<State> = createMiddleware { getState, dispatch, next in
            return { action in
                result += "m-\(action) "
                next(action)
            }
        }
        let reducer: Reducer<State> = { action, state in
            result += "r-\(action) "
            return state
        }
        let store = Store<State>(state: initialState, reducer: reducer, middleware: [middleware])

        store.dispatch("a")
        store.dispatch("b")
        store.dispatch("c")
        store.dispatch("d")

        XCTAssertEqual(result, "m-a r-a m-b r-b m-c r-c m-d r-d ")
    }

    func testMiddleware_evenIfRunOnDifferentQueues_isExecutedSequentially() {
        func asyncMiddleware(id: String, qos: DispatchQoS.QoSClass) -> Middleware<State> {
            let asyncExpectation = expectation(description: "\(id) async middleware expectation")
            return createMiddleware { getState, dispatch, next in
                return { action in
                    DispatchQueue.global(qos: qos).async {
                        next("\(action) \(id)");
                        asyncExpectation.fulfill()
                    }
                }
            }
        }

        var result = ""
        let reducer: Reducer<State> = { action, state in
            result += action as! StringAction
            return state
        }
        let middleware1 = asyncMiddleware(id: "first", qos: .default)
        let middleware2 = asyncMiddleware(id: "second", qos: .userInteractive)
        let middleware3 = asyncMiddleware(id: "third", qos: .background)
        let store = Store<State>(state: initialState, reducer: reducer, middleware: [middleware1, middleware2, middleware3])

        store.dispatch(nopAction)

        waitForExpectations(timeout: 0.1) { e in
            XCTAssertEqual(result, "action first second third")
        }
    }

    func testStore_whenSubscribing_startReceivingStateUpdates() {
        let reducer: Reducer<State> = { action, state in
            switch action {
            case let action as StringAction where action == "mul": return state * 2
            case let action as StringAction where action == "inc": return state + 3
            default: return state
            }
        }
        let store = Store<State>(state: 3, reducer: reducer)

        var result: [State] = []
        store.subscribe { state in
            result.append(state)
        }
        store.dispatch("mul")
        store.dispatch("inc")

        XCTAssertEqual(result, [6, 9])
    }

    func testSubscribeToStore_whenSkippingRepeats_receiveUniqueStateUpdates() {
        let actions: [StringAction] = ["1", "2", "1", "1", "3", "3", "5", "2"]
        let reducer: Reducer<State> = { action, state in
            Int(action as! StringAction)!
        }
        let store = Store<State>(state: initialState, reducer: reducer)

        var result: [State] = []
        store.subscribe(skipRepeats: true) { state in
            result.append(state)
        }
        actions.forEach(store.dispatch)

        XCTAssertEqual(result, [1, 2, 1, 3, 5, 2])
    }

    func testSubscribeToStore_whenNotSkippingRepeats_receiveDuplicatedStateUpdates() {
        let actions: [StringAction] = ["1", "2", "1", "1", "3", "3", "5", "2"]
        let reducer: Reducer<State> = { action, state in
            Int(action as! StringAction)!
        }
        let store = Store<State>(state: initialState, reducer: reducer)

        var result: [State] = []
        store.subscribe(skipRepeats: false) { state in
            result.append(state)
        }
        actions.forEach(store.dispatch)

        XCTAssertEqual(result, [1, 2, 1, 1, 3, 3, 5, 2])
    }

    func testStore_whenSubscribing_ReceiveStateUpdatesOnSelectedQueue() {
        let id = "testStore_whenSubscribing_ReceiveStateUpdatesOnSelectedQueue"
        let queueId = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: id)
        queue.setSpecific(key: queueId, value: id)
        let store = Store<State>(state: initialState, reducer: nopReducer)

        var result: String!
        let queueExpectation = expectation(description: id)
        store.subscribe(on: queue) { state in
            result = DispatchQueue.getSpecific(key: queueId)
            queueExpectation.fulfill()
        }
        store.dispatch(nopAction)

        waitForExpectations(timeout: 0.1) { e in
            queue.setSpecific(key: queueId, value: nil)

            XCTAssertEqual(result, id)
        }
    }

    func testStore_whenSubscribingWithoutSelectedQueue_butDidSoBefore_receiveStateUpdatesOnDefaultQueue() {
        let id = "testStore_whenSubscribingWithoutSelectedQueue_butDidSoBefore_receiveStateUpdatesOnDefaultQueue"
        let queueId = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: id)
        queue.setSpecific(key: queueId, value: id)
        let store = Store<State>(state: initialState, reducer: nopReducer)

        var result: String!
        let onQueueExpectation = expectation(description: "\(id) on queue")
        let defaultQueueExpectation = expectation(description: "\(id) default queue")
        store.subscribe(on: queue) { state in
            onQueueExpectation.fulfill()
        }
        store.subscribe { state in
            defaultQueueExpectation.fulfill()
            result = DispatchQueue.getSpecific(key: queueId)
        }
        store.dispatch(nopAction)

        waitForExpectations(timeout: 0.1) { e in
            queue.setSpecific(key: queueId, value: nil)

            XCTAssertNotEqual(result, id)
        }
    }

    func testStore_whenUnsubscribing_stopReceivingStateUpdates() {
        let reducer: Reducer<State> = { action, state in
            return Int(action as! StringAction)!
        }
        let store = Store<State>(state: initialState, reducer: reducer)

        var result: [State] = []
        let disposable = store.subscribe { state in
            result.append(state)
        }
        store.dispatch("1")
        store.dispatch("2")
        store.dispatch("3")

        disposable.dispose()
        store.dispatch("4")
        store.dispatch("5")

        XCTAssertEqual(result, [1, 2, 3])
    }

    func testStore_whenObserving_andSubscribingToObserver_startReceivingStateUpdates() {
        let reducer: Reducer<State> = { action, state in
            switch action {
            case let action as StringAction where action == "mul": return state * 2
            case let action as StringAction where action == "inc": return state + 3
            default: return state
            }
        }
        let store = Store<State>(state: 3, reducer: reducer)

        var result: [State] = []
        store.observe().subscribe { state in
            result.append(state)
        }
        store.dispatch("mul")
        store.dispatch("inc")

        XCTAssertEqual(result, [6, 9])
    }

    func testStore_whenUnsubscribingFromObserver_stopReceivingStateUpdates() {
        let reducer: Reducer<State> = { action, state in
            return Int(action as! StringAction)!
        }
        let store = Store<State>(state: initialState, reducer: reducer)

        var result: [State] = []
        let disposable = store.observe().subscribe { state in
            result.append(state)
        }
        store.dispatch("1")
        store.dispatch("2")
        store.dispatch("3")

        disposable.dispose()
        store.dispatch("4")
        store.dispatch("5")

        XCTAssertEqual(result, [1, 2, 3])
    }
}