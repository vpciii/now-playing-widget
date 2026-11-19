import AppKit
import NowPlayingCore
import WidgetKit

/// Watches Music and keeps the widget's snapshot current. Main thread only.
final class NowPlayingCoordinator {
    private let music = AppleScriptMusic()
    private let relay = CommandRelay()
    private let queueSource = SwiftScriptQueueSource()
    private let artworkFetcher = ArtworkFetcher()
    private var observers: [NSObjectProtocol] = []
    /// Bumped on every refresh so answers that arrive after a newer track
    /// change are dropped.
    private var generation = 0
    /// Which downloaded artwork URL each artwork file currently holds.
    private var downloaded: [String: URL] = [:]

    func start() {
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: .main
        ) { [weak self] _ in
            Log.music.info("track change notification")
            self?.refresh()
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.bundleIdentifier == AppleScriptMusic.musicBundleID { self?.refresh() }
        })
        relay.start { [weak self] command in self?.perform(command) }
        refresh()
    }

    func stop() {
        generation += 1
        publish(.notPlaying(at: Date()))
    }

    private func refresh() {
        generation += 1
        let current = generation
        let now = Date()

        let reading: MusicReading?
        do {
            reading = try music.read()
        } catch {
            Log.music.error("could not read Music: \(String(describing: error), privacy: .public)")
            reading = nil
        }
        guard let reading, reading.state != .stopped else {
            publish(SnapshotBuilder.build(music: reading, queue: .failed(reason: "not playing"), now: now))
            return
        }

        queueSource.fetch { [weak self] queue in
            guard let self, self.generation == current else { return }
            if case .failed(let reason) = queue {
                Log.queue.error("queue source failed: \(reason, privacy: .public)")
            }
            self.publish(music: reading, queue: queue, now: now, generation: current)
        }
    }

    /// Publishes once any artwork downloads are in place, or straight away
    /// when there are none. Slow downloads publish without the images first
    /// and once more when they have all arrived.
    private func publish(music: MusicReading, queue: QueueResult, now: Date, generation current: Int) {
        var files: [String: String] = [:]
        var wanted: [(file: String, url: ApprovedArtworkURL)] = []

        func want(_ file: String, from approved: ApprovedArtworkURL?) {
            guard let approved else {
                downloaded[file] = nil
                ArtworkWriter.remove(file)
                return
            }
            if downloaded[file] == approved.url {
                files[file] = file
            } else {
                wanted.append((file, approved))
            }
        }

        func snapshot() -> Snapshot {
            SnapshotBuilder.build(music: music, queue: queue, now: now,
                                  currentArtworkFile: files[ArtworkFile.current],
                                  upcomingArtworkFile: files[ArtworkFile.upcoming])
        }

        switch CurrentArtworkSource.choose(music: music, queue: queue) {
        case .download(let approved):
            want(ArtworkFile.current, from: approved)
        case .appleScript:
            // No URL for this song (a local file, or the queue source failed).
            // AppleScript can still be returning the previous song's artwork
            // this soon after a track change, so read it again shortly.
            downloaded[ArtworkFile.current] = nil
            let first = self.music.currentArtwork()
            if let first, ArtworkWriter.write(first, as: ArtworkFile.current) != nil {
                files[ArtworkFile.current] = ArtworkFile.current
            } else {
                ArtworkWriter.remove(ArtworkFile.current)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self, self.generation == current else { return }
                let second = self.music.currentArtwork()
                guard second != first else { return }
                if let second, ArtworkWriter.write(second, as: ArtworkFile.current) != nil {
                    files[ArtworkFile.current] = ArtworkFile.current
                } else {
                    files[ArtworkFile.current] = nil
                    ArtworkWriter.remove(ArtworkFile.current)
                }
                Log.music.info("artwork changed on second read; republishing")
                self.publish(snapshot())
            }
        }
        want(ArtworkFile.upcoming,
             from: ArtworkURLPolicy.approve(SnapshotBuilder.upcomingItem(after: music, in: queue)?.artworkURL))

        guard !wanted.isEmpty else {
            publish(snapshot())
            return
        }

        var remaining = wanted.count
        let deadline = DispatchWorkItem { [weak self] in
            guard let self, self.generation == current else { return }
            self.publish(snapshot())
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: deadline)

        for (file, approved) in wanted {
            artworkFetcher.fetch(approved) { [weak self] data in
                guard let self, self.generation == current else { return }
                if let data, ArtworkWriter.write(data, as: file) != nil {
                    files[file] = file
                    self.downloaded[file] = approved.url
                } else {
                    self.downloaded[file] = nil
                    ArtworkWriter.remove(file)
                }
                remaining -= 1
                if remaining == 0 {
                    deadline.cancel()
                    self.publish(snapshot())
                }
            }
        }
    }

    private func perform(_ command: PlayerCommand) {
        Log.commands.info("relayed command: \(command.rawValue, privacy: .public)")
        do {
            try CommandDispatcher.handle(notificationName: command.notificationName, commander: music)
        } catch {
            Log.commands.error("command failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func publish(_ snapshot: Snapshot) {
        do {
            try SharedContainer.write(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSupport.widgetKind)
            Log.widget.info("""
                reload requested: \(snapshot.state.rawValue, privacy: .public) \
                "\(snapshot.current?.title ?? "-", privacy: .public)" \
                artwork=\(snapshot.current?.artworkFile != nil, privacy: .public) \
                upcoming="\(snapshot.upcoming?.title ?? "unavailable", privacy: .public)" \
                upcomingArtwork=\(snapshot.upcoming?.artworkFile != nil, privacy: .public)
                """)
        } catch {
            Log.widget.error("could not write snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }
}
