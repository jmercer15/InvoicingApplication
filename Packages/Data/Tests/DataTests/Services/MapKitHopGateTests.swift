@testable import Data
import Testing

@Suite struct MapKitHopGateTests {
    @Test func cancellationRemovesQueuedWaiterWithoutConsumingSlot() async {
        let gate = MapKitHopGate(maxConcurrent: 1)
        #expect(await gate.acquire())

        let queuedAcquire = Task { await gate.acquire() }
        await waitForWaiters(on: gate, count: 1)
        queuedAcquire.cancel()

        #expect(await queuedAcquire.value == false)
        #expect(await gate.pendingWaiterCount() == 0)
        await gate.release()
    }

    @Test func releaseResumesExactlyOneQueuedWaiter() async {
        let gate = MapKitHopGate(maxConcurrent: 1)
        #expect(await gate.acquire())

        let firstWaiter = Task { await gate.acquire() }
        let secondWaiter = Task { await gate.acquire() }
        await waitForWaiters(on: gate, count: 2)

        await gate.release()
        await waitForWaiters(on: gate, count: 1)

        await gate.release()
        let firstResult = await firstWaiter.value
        let secondResult = await secondWaiter.value
        #expect(firstResult && secondResult)
        await gate.release()
    }

    private func waitForWaiters(on gate: MapKitHopGate, count: Int) async {
        for _ in 0 ..< 100 {
            if await gate.pendingWaiterCount() == count { return }
            await Task.yield()
        }
        Issue.record("Timed out waiting for \(count) MapKit hop waiters.")
    }
}
