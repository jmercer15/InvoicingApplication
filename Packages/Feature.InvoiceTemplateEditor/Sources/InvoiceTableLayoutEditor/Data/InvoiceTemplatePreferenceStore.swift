import CoreGraphics
import Foundation

/// Complete defaults owned by Template Editor. Page setup belongs beside visual formatting so
/// every control in that workspace survives relaunch and seeds newly created invoices.
struct InvoiceTemplateDefaults: Equatable, Codable {
    static let currentVersion = 2

    var version = currentVersion
    var paperSize: PaperSize = .default
    var pageOrientation: PageOrientation = .portrait
    var configuration: InvoiceTemplateConfiguration = .default

    private enum CodingKeys: String, CodingKey {
        case version, paperSize, pageOrientation, configuration
    }

    init(
        version: Int = currentVersion,
        paperSize: PaperSize = .default,
        pageOrientation: PageOrientation = .portrait,
        configuration: InvoiceTemplateConfiguration = .default
    ) {
        self.version = version
        self.paperSize = paperSize
        self.pageOrientation = pageOrientation
        self.configuration = configuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Absence distinguishes legacy raw InvoiceTemplateConfiguration payloads from envelope v2.
        guard container.contains(.configuration) else {
            throw DecodingError.keyNotFound(
                CodingKeys.configuration,
                .init(codingPath: decoder.codingPath, debugDescription: "Not a template defaults envelope")
            )
        }
        version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? Self.currentVersion
        paperSize = (try? container.decodeIfPresent(PaperSize.self, forKey: .paperSize)) ?? .default
        pageOrientation = (try? container.decodeIfPresent(PageOrientation.self, forKey: .pageOrientation)) ?? .portrait
        configuration = (try? container.decodeIfPresent(
            InvoiceTemplateConfiguration.self,
            forKey: .configuration
        )) ?? .default
    }

    var sanitized: Self {
        var value = self
        value.version = Self.currentVersion
        value.configuration.customPageWidthPoints = InvoiceTemplateLayoutLimits.optionalValue(
            value.configuration.customPageWidthPoints,
            clampedTo: InvoiceTemplateLayoutLimits.pageDimensionRange
        )
        value.configuration.customPageHeightPoints = InvoiceTemplateLayoutLimits.optionalValue(
            value.configuration.customPageHeightPoints,
            clampedTo: InvoiceTemplateLayoutLimits.pageDimensionRange
        )
        value.configuration.customTypographyScale = InvoiceTemplateLayoutLimits.optionalValue(
            value.configuration.customTypographyScale,
            clampedTo: InvoiceTemplateLayoutLimits.typographyScaleRange
        )
        value.configuration.customSpacingScale = InvoiceTemplateLayoutLimits.optionalValue(
            value.configuration.customSpacingScale,
            clampedTo: InvoiceTemplateLayoutLimits.spacingScaleRange
        )
        value.configuration.customBorderWidth = InvoiceTemplateLayoutLimits.optionalValue(
            value.configuration.customBorderWidth,
            clampedTo: InvoiceTemplateLayoutLimits.borderWidthRange
        )
        if let accent = value.configuration.customAccentColor {
            value.configuration.customAccentColor = InvoiceCustomAccentColor(
                red: InvoiceTemplateLayoutLimits.colorComponent(accent.red),
                green: InvoiceTemplateLayoutLimits.colorComponent(accent.green),
                blue: InvoiceTemplateLayoutLimits.colorComponent(accent.blue),
                opacity: InvoiceTemplateLayoutLimits.colorComponent(accent.opacity)
            )
        }

        let standardSize = value.paperSize.sizePoints(for: value.pageOrientation)
        let pageSize = CGSize(
            width: value.configuration.customPageWidthPoints.map(
                InvoiceTemplateLayoutLimits.pageDimension
            ) ?? standardSize.width,
            height: value.configuration.customPageHeightPoints.map(
                InvoiceTemplateLayoutLimits.pageDimension
            ) ?? standardSize.height
        )
        if let margin = value.configuration.customMarginPoints {
            value.configuration.customMarginPoints = Double(
                InvoiceTemplateLayoutLimits.effectiveMargin(margin, pageSize: pageSize)
            )
        }
        return value
    }
}

/// Stores application template defaults independently from persisted invoice content.
enum InvoiceTemplatePreferenceStore {
    static let preferenceKey = "InvoiceTemplateEditor.TemplateConfiguration.v1"

    static func loadDefaults(from preferences: UserDefaults = .standard) -> InvoiceTemplateDefaults {
        guard let data = preferences.data(forKey: preferenceKey) else { return InvoiceTemplateDefaults() }
        if let defaults = try? JSONDecoder().decode(InvoiceTemplateDefaults.self, from: data) {
            return defaults.sanitized
        }
        // v1 stored InvoiceTemplateConfiguration directly. Preserve it while supplying newly
        // introduced page-setup defaults.
        if let legacyConfiguration = try? JSONDecoder().decode(
            InvoiceTemplateConfiguration.self,
            from: data
        ) {
            return InvoiceTemplateDefaults(configuration: legacyConfiguration).sanitized
        }
        return InvoiceTemplateDefaults()
    }

    static func load(from preferences: UserDefaults = .standard) -> InvoiceTemplateConfiguration {
        loadDefaults(from: preferences).configuration
    }

    @discardableResult
    static func save(
        _ configuration: InvoiceTemplateConfiguration,
        to preferences: UserDefaults = .standard
    ) -> Bool {
        var defaults = loadDefaults(from: preferences)
        defaults.configuration = configuration
        return save(defaults, to: preferences)
    }

    @discardableResult
    static func save(
        _ defaults: InvoiceTemplateDefaults,
        to preferences: UserDefaults = .standard
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(defaults.sanitized) else { return false }
        preferences.set(data, forKey: preferenceKey)
        return preferences.data(forKey: preferenceKey) == data
    }
}
