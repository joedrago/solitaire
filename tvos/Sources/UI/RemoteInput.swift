import SwiftUI
import UIKit

// UIKit bridge that captures Siri Remote presses (the same trick as duplex's
// PlayerRemoteInput). The wrapped view is transparent, fills the screen, and
// is the only focusable thing in the app, so every press lands here. SwiftUI's
// onMoveCommand can't do press-and-hold repeat or distinguish select
// tap-vs-long-press, both of which we want.
struct RemoteInput: UIViewControllerRepresentable {
    @ObservedObject var model: AppModel

    func makeUIViewController(context: Context) -> RemotePressCaptureVC {
        let vc = RemotePressCaptureVC()
        update(vc)
        return vc
    }

    func updateUIViewController(_ vc: RemotePressCaptureVC, context: Context) {
        update(vc)
    }

    private func update(_ vc: RemotePressCaptureVC) {
        vc.onDirection = { [weak model] dir, isRepeat in model?.onDirection(dir, isRepeat: isRepeat) }
        vc.onSelectTap = { [weak model] in model?.onSelect() }
        vc.onSelectLongPress = { [weak model] in model?.onSelectLong() }
        vc.onPlayPauseTap = { [weak model] in model?.onPlayPause() }
        vc.menuWantsCapture = { [weak model] in model?.menuWantsCapture() ?? false }
        vc.onMenuTap = { [weak model] in model?.onMenu() }
        vc.refreshFocus()
    }
}

final class RemotePressCaptureVC: UIViewController {
    var onDirection: (Direction, Bool) -> Void = { _, _ in }
    var onSelectTap: () -> Void = {}
    var onSelectLongPress: () -> Void = {}
    var onPlayPauseTap: () -> Void = {}
    var menuWantsCapture: () -> Bool = { false }
    var onMenuTap: () -> Void = {}

    private var repeatTimer: Timer?
    private var heldDirection: Direction?

    private var selectLongPressTimer: Timer?
    private var selectLongPressFired = false

    private var menuCaptured = false

    override func loadView() {
        let v = AlwaysFocusableView()
        v.backgroundColor = .clear
        view = v
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] { [view] }

    func refreshFocus() {
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshFocus()
    }


    private func direction(for press: UIPress) -> Direction? {
        switch press.type {
        case .upArrow: return .up
        case .downArrow: return .down
        case .leftArrow: return .left
        case .rightArrow: return .right
        default: return nil
        }
    }

    private func beginDirection(_ dir: Direction) {
        onDirection(dir, false)
        heldDirection = dir
        repeatTimer?.invalidate()
        // Hold-to-repeat: handy for walking 13 columns of Baker's Dozen.
        // Repeat ticks pass isRepeat=true so edge-wrapping only fires on a
        // real press, never while a held direction is auto-pulsing.
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                guard let self, let held = self.heldDirection else { return }
                self.onDirection(held, true)
            }
        }
    }

    private func endDirection(_ dir: Direction) {
        if heldDirection == dir {
            heldDirection = nil
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            if let dir = direction(for: press) {
                beginDirection(dir)
            } else {
                switch press.type {
                case .select:
                    selectLongPressFired = false
                    selectLongPressTimer?.invalidate()
                    selectLongPressTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                        guard let self else { return }
                        self.selectLongPressFired = true
                        self.onSelectLongPress()
                    }
                case .playPause:
                    break // fire on release
                case .menu:
                    menuCaptured = menuWantsCapture()
                    if !menuCaptured {
                        unhandled.insert(press)
                    }
                default:
                    unhandled.insert(press)
                }
            }
        }
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            if let dir = direction(for: press) {
                endDirection(dir)
            } else {
                switch press.type {
                case .select:
                    selectLongPressTimer?.invalidate()
                    selectLongPressTimer = nil
                    if !selectLongPressFired {
                        onSelectTap()
                    }
                case .playPause:
                    onPlayPauseTap()
                case .menu:
                    if menuCaptured {
                        onMenuTap()
                    } else {
                        unhandled.insert(press)
                    }
                default:
                    unhandled.insert(press)
                }
            }
        }
        if !unhandled.isEmpty {
            super.pressesEnded(unhandled, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let dir = direction(for: press) {
                endDirection(dir)
            } else if press.type == .select {
                selectLongPressTimer?.invalidate()
                selectLongPressTimer = nil
            }
        }
        super.pressesCancelled(presses, with: event)
    }
}

final class AlwaysFocusableView: UIView {
    override var canBecomeFocused: Bool { true }
}
