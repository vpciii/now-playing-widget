import Foundation
import NowPlayingCore

/// Receives the widget's control presses. The widget posts one distributed
/// notification per command; this turns each into a `PlayerCommand`.
final class CommandRelay {
    private var observers: [NSObjectProtocol] = []

    func start(handler: @escaping (PlayerCommand) -> Void) {
        let center = DistributedNotificationCenter.default()
        for command in PlayerCommand.allCases {
            let observer = center.addObserver(
                forName: Notification.Name(command.notificationName), object: nil, queue: .main
            ) { _ in handler(command) }
            observers.append(observer)
        }
    }

    deinit {
        observers.forEach(DistributedNotificationCenter.default().removeObserver)
    }
}
