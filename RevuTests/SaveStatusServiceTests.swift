import Foundation
import Testing
@testable import Revu

@Suite("SaveStatusService")
struct SaveStatusServiceTests {

    @Test("Initial status is idle")
    @MainActor
    func initialStatusIsIdle() {
        let service = SaveStatusService()
        #expect(service.status == .idle)
    }

    @Test("reportError sets error status")
    @MainActor
    func reportErrorSetsErrorStatus() {
        let service = SaveStatusService()
        service.reportError()
        #expect(service.status == .error)
    }
}
