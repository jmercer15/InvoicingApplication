import Core
import SwiftData
import SwiftUI

struct ClaimBatchesQueryList: View {
    @Query(sort: \BulkClaimBatch.createdAt, order: .reverse) private var batches: [BulkClaimBatch]

    var body: some View {
        List {
            ForEach(batches) { batch in
                NavigationLink(value: batch.id) {
                    ClaimBatchRowView(batch: batch)
                }
            }
        }
    }
}

private struct ClaimBatchRowView: View {
    let batch: BulkClaimBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(batch.exportFileName ?? "Batch \(batch.id.uuidString.prefix(8))...")
                .font(.headline)
            Text("\(batch.rowCount) lines · \(batch.status)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
