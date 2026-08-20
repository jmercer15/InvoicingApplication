import Foundation
import Testing
@testable import SharedUI

@Suite struct AppToolbarComponentsTests {
    @Test func MenuLabelsExposeActiveCountsOnlyWhenNeeded() {
        #expect(AppToolbarMenuLabel.withCount("Filter", count: 0) == "Filter")
        #expect(AppToolbarMenuLabel.withCount("Filter", count: 3) == "Filter (3)")
        #expect(AppToolbarMenuLabel.withActiveFlag("Category", isActive: false) == "Category")
        #expect(AppToolbarMenuLabel.withActiveFlag("Category", isActive: true) == "Category (1)")
    }

    @Test func SharedToolbarControlsRetainAccessibleAndSemanticImplementations() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: packageRoot
                .appendingPathComponent("Sources/SharedUI/Components/AppToolbarComponents.swift"),
            encoding: .utf8
        )

        #expect(source.contains("Button(accessibilityLabel, systemImage: systemName"))
        #expect(source.contains(".accessibilityValue(isOn ? \"On\" : \"Off\")"))
        #expect(source.contains("ToolbarItem(placement: .cancellationAction)"))
        #expect(source.contains("ToolbarItem(placement: .confirmationAction)"))
        #expect(source.contains("Button(\"Previous period\", systemImage: \"chevron.left\""))
        #expect(source.contains("Button(\"Next period\", systemImage: \"chevron.right\""))
    }
}
