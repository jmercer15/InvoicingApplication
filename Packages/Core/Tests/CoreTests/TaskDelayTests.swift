import Testing
import Core

@Suite struct TaskDelayTests {
    @Test func completedDelayReportsSuccess() async {
        let completed = await Task.waitUnlessCancelled(for: .zero)

        #expect(completed)
    }

    @Test func cancelledDelayReportsCancellation() async {
        let delay = Task { await Task.waitUnlessCancelled(for: .seconds(60)) }
        delay.cancel()

        #expect(await delay.value == false)
    }
}
