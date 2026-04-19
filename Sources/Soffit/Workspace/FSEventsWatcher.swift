import CoreServices
import Foundation

final class FSEventsWatcher {
    private var stream: FSEventStreamRef?
    private let callback: () -> Void

    init?(path: String, onChange: @escaping () -> Void) {
        self.callback = onChange
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let pathsToWatch = [path] as CFArray
        let flags: UInt32 = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, count, _, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<FSEventsWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.callback()
            },
            &context,
            pathsToWatch,
            UInt64(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else { return nil }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
