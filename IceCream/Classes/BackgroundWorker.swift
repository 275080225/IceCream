//
//  BackgroundWorker.swift
//  IceCream
//
//  Created by Kit Forge on 5/9/19.
//

import Foundation
import RealmSwift

// Based on https://academy.realm.io/posts/realm-notifications-on-background-threads-with-swift/
// Tweaked a little by Yue Cai

class BackgroundWorker: NSObject {

    static let shared = BackgroundWorker()

    private final class BlockBox: NSObject {
        let block: () -> Void
        init(_ block: @escaping () -> Void) { self.block = block }
    }

    private let lock = NSLock()
    private var thread: Thread?

    private func workerThread() -> Thread {
        lock.lock()
        defer { lock.unlock() }
        if let thread = thread { return thread }
        let newThread = Thread { [weak self] in
            while let self = self, let thread = self.thread, !thread.isCancelled {
                RunLoop.current.run(mode: .default, before: Date.distantFuture)
            }
            Thread.exit()
        }
        newThread.name = "\(String(describing: self))-\(UUID().uuidString)"
        thread = newThread
        newThread.start()
        return newThread
    }

    func start(_ block: @escaping () -> Void) {
        // Each block travels with its own perform call; sharing one stored property across threads is a data race.
        perform(#selector(runBlock(_:)),
                on: workerThread(),
                with: BlockBox(block),
                waitUntilDone: true,
                modes: [RunLoop.Mode.default.rawValue])
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        thread?.cancel()
    }

    @objc private func runBlock(_ box: BlockBox) {
        box.block()
    }
}
