import Foundation
import Testing
import TerminalKit
@testable import Relay

@MainActor
struct SessionStateTests {
    @Test func processStatusesMapToStates() {
        #expect(SessionState(.starting) == .starting)
        #expect(SessionState(.running) == .running)
        #expect(SessionState(.exited(code: 3)) == .exited(code: 3))
        #expect(SessionState(.failed("nope")) == .failed)
        #expect(SessionState(.closed) == .notStarted)
    }

    @Test func labelsNameTheExitCodeOnlyWhenItIsNonZero() {
        #expect(SessionState.running.label == "Running")
        #expect(SessionState.exited(code: 0).label == "Exited")
        #expect(SessionState.exited(code: 1).label == "Exited (1)")
        #expect(SessionState.failed.label == "Failed")
    }

    @Test func onlyFailuresAndNonZeroExitsAreProblems() {
        #expect(SessionState.failed.isProblem)
        #expect(SessionState.exited(code: 1).isProblem)
        #expect(!SessionState.exited(code: 0).isProblem)
        #expect(!SessionState.exited(code: nil).isProblem)
        #expect(!SessionState.running.isProblem)
        #expect(!SessionState.starting.isProblem)
    }

    @Test func aPreviewManagerReportsPreview() {
        let manager = TerminalSessionManager(allowsLaunching: false)
        let session = Session(type: .shellPreset)
        #expect(manager.state(for: session) == .preview)
        #expect(manager.status(for: session) == "Preview")
    }

    @Test func aSessionNobodyStartedIsNotStarted() {
        let manager = TerminalSessionManager()
        #expect(manager.state(for: Session(type: .shellPreset)) == .notStarted)
    }
}
