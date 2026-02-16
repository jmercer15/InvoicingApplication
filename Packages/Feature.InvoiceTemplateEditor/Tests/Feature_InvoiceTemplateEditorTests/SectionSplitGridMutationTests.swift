import XCTest
import CoreGraphics
@testable import Feature_InvoiceTemplateEditor

final class SectionSplitGridMutationTests: XCTestCase {

    func testInsertGridRowPreservesMetadataMapping() {
        var split = makeConfiguredGridSplit()
        let original = split

        split.insertGridRow(at: 1)

        XCTAssertEqual(split.gridRows, 3)
        XCTAssertEqual(split.gridColumns, 2)
        XCTAssertEqual(split.splitCount, 6)

        assertSlotMapped(from: 0, to: 0, old: original, new: split)
        assertSlotMapped(from: 1, to: 1, old: original, new: split)
        assertSlotMapped(from: 2, to: 4, old: original, new: split)
        assertSlotMapped(from: 3, to: 5, old: original, new: split)

        assertEmptySlot(2, in: split)
        assertEmptySlot(3, in: split)
    }

    func testInsertGridColumnPreservesMetadataMapping() {
        var split = makeConfiguredGridSplit()
        let original = split

        split.insertGridColumn(at: 1)

        XCTAssertEqual(split.gridRows, 2)
        XCTAssertEqual(split.gridColumns, 3)
        XCTAssertEqual(split.splitCount, 6)

        assertSlotMapped(from: 0, to: 0, old: original, new: split)
        assertSlotMapped(from: 1, to: 2, old: original, new: split)
        assertSlotMapped(from: 2, to: 3, old: original, new: split)
        assertSlotMapped(from: 3, to: 5, old: original, new: split)

        assertEmptySlot(1, in: split)
        assertEmptySlot(4, in: split)
    }

    func testDeleteGridRowReindexesMetadataAndReturnsOrphanedComponents() {
        var split = makeConfiguredGridSplit()
        let original = split

        let orphaned = split.deleteGridRow(at: 0)

        XCTAssertEqual(split.gridRows, 1)
        XCTAssertEqual(split.gridColumns, 2)
        XCTAssertEqual(split.splitCount, 2)

        assertSlotMapped(from: 2, to: 0, old: original, new: split)
        assertSlotMapped(from: 3, to: 1, old: original, new: split)

        let expectedOrphans = Set([
            original.childComponents[0]!.first!.id,
            original.childComponents[1]!.first!.id
        ])
        XCTAssertEqual(Set(orphaned.map(\.id)), expectedOrphans)
    }

    func testDeleteGridColumnReindexesMetadataAndReturnsOrphanedComponents() {
        var split = makeConfiguredGridSplit()
        let original = split

        let orphaned = split.deleteGridColumn(at: 1)

        XCTAssertEqual(split.gridRows, 2)
        XCTAssertEqual(split.gridColumns, 1)
        XCTAssertEqual(split.splitCount, 2)

        assertSlotMapped(from: 0, to: 0, old: original, new: split)
        assertSlotMapped(from: 2, to: 1, old: original, new: split)

        let expectedOrphans = Set([
            original.childComponents[1]!.first!.id,
            original.childComponents[3]!.first!.id
        ])
        XCTAssertEqual(Set(orphaned.map(\.id)), expectedOrphans)
    }

    private func makeConfiguredGridSplit() -> SectionSplit {
        var split = SectionSplit(gridRows: 2, gridColumns: 2)

        for index in 0..<4 {
            split.childComponents[index] = [makeComponent(seed: index)]
            split.childLabels[index] = "Label \(index)"
            split.childAlignments[index] = alignment(for: index)
            split.childWidthSizingModes[index] = index.isMultiple(of: 2) ? .expand : .shrink
            split.childHeightSizingModes[index] = index.isMultiple(of: 2) ? .shrink : .expand
            split.childPaddings[index] = SectionSplit.PaddingInsets(
                top: CGFloat(index),
                leading: CGFloat(index + 1),
                bottom: CGFloat(index + 2),
                trailing: CGFloat(index + 3)
            )
        }

        split.children[2] = SectionSplit(direction: .horizontal, splitCount: 2)

        return split
    }

    private func makeComponent(seed: Int) -> InvoiceComponent {
        InvoiceComponent(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", seed + 1))!,
            type: .notes,
            position: .zero,
            size: CGSize(width: 120, height: 40)
        )
    }

    private func alignment(for index: Int) -> SectionSplit.LeafAlignment {
        let horizontal: SectionSplit.LeafAlignment.HorizontalAlignment
        switch index % 3 {
        case 0: horizontal = .leading
        case 1: horizontal = .center
        default: horizontal = .trailing
        }

        let vertical: SectionSplit.LeafAlignment.VerticalAlignment
        switch index % 3 {
        case 0: vertical = .top
        case 1: vertical = .center
        default: vertical = .bottom
        }

        return SectionSplit.LeafAlignment(horizontal: horizontal, vertical: vertical)
    }

    private func assertSlotMapped(
        from oldIndex: Int,
        to newIndex: Int,
        old: SectionSplit,
        new: SectionSplit,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let oldChild = old.children[oldIndex] {
            XCTAssertEqual(new.children[newIndex]?.id, oldChild.id, file: file, line: line)
        } else {
            XCTAssertNil(new.children[newIndex], file: file, line: line)
        }

        XCTAssertEqual(
            new.childComponents[newIndex]?.map(\.id),
            old.childComponents[oldIndex]?.map(\.id),
            file: file,
            line: line
        )
        XCTAssertEqual(new.childLabels[newIndex], old.childLabels[oldIndex], file: file, line: line)
        XCTAssertEqual(new.childAlignments[newIndex], old.childAlignments[oldIndex], file: file, line: line)
        XCTAssertEqual(new.childWidthSizingModes[newIndex], old.childWidthSizingModes[oldIndex], file: file, line: line)
        XCTAssertEqual(new.childHeightSizingModes[newIndex], old.childHeightSizingModes[oldIndex], file: file, line: line)
        XCTAssertEqual(new.childPaddings[newIndex], old.childPaddings[oldIndex], file: file, line: line)
    }

    private func assertEmptySlot(
        _ index: Int,
        in split: SectionSplit,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNil(split.children[index], file: file, line: line)
        XCTAssertNil(split.childComponents[index], file: file, line: line)
        XCTAssertNil(split.childLabels[index], file: file, line: line)
        XCTAssertNil(split.childAlignments[index], file: file, line: line)
        XCTAssertEqual(split.childWidthSizingModes[index], .fixed, file: file, line: line)
        XCTAssertEqual(split.childHeightSizingModes[index], .fixed, file: file, line: line)
        XCTAssertEqual(split.childPaddings[index], .zero, file: file, line: line)
    }
}
