//
//  Store.swift
//  SwiftyRedux
//
//  Created by Alexander Voronov on 12/16/18.
//  Copyright © 2018 Alex Voronov. All rights reserved.
//

import Dispatch

public final class Store<State> {
    private let reducer: Reducer<State>
    private let middleware: Middleware<State>
    private let queue: ReadWriteQueue
    private let (observable, observer): (Observable<State>, Observer<State>)

    private var currentState: State
    public var state: State {
        return queue.read { currentState }
    }

    public init(id: String = "redux.store", state: State, reducer: @escaping Reducer<State>, middleware: [Middleware<State>] = []) {
        self.queue = ReadWriteQueue(label: "\(id).queue")
        self.currentState = state
        self.reducer = reducer
        self.middleware = applyMiddleware(middleware)

        (observable, observer) = Observable<State>.pipe(id: "\(id).observable")
    }

    public func dispatch(_ action: Action) {
        let dispatchFunction = middleware(
            { self.state },
            { [weak self] in self?.dispatch($0) },
            { [weak self] action in self?.defaultDispatch(from: action) }
        )
        dispatchFunction(action)
    }

    private func defaultDispatch(from action: Action) {
        queue.write {
            self.currentState = self.reducer(action, self.currentState)
            self.observer.update(self.currentState)
        }
    }

    @discardableResult
    public func subscribe(on queue: DispatchQueue? = nil, observer: @escaping (State) -> Void) -> Disposable {
        return observable.subscribe(on: queue, observer: observer)
    }

    public func observe() -> Observable<State> {
        return observable
    }
}