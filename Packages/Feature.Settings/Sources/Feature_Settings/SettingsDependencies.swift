import Core
import Data
import SwiftData
import SwiftUI

/// Persistence and background actors for settings flows. Shared workspace services
/// (`geocodingService`, `eventKitSyncService`, etc.) are supplied via `EnvironmentValues`.
///
/// **Design:** A single optional `\.settingsServices` bundle (rather than one environment key per actor)
/// keeps the Settings window’s injection small. The app sets this only after database + actors exist;
/// before that, `settingsServices == nil` and the Settings scene should show loading (see `SettingsColumns`).
@MainActor
public final class SettingsServices {
    private let database: AppDatabase
    private let dataWipeService: DataWipeService

    private var _importExportCoordinator: ImportExportCoordinator?
    private var _travelChargeAutomationActor: TravelChargeAutomationActor?

    public init(database: AppDatabase, dataWipeService: DataWipeService) {
        self.database = database
        self.dataWipeService = dataWipeService
    }

    public var importExportCoordinator: ImportExportCoordinator {
        if let coordinator = _importExportCoordinator { return coordinator }
        let coordinator = ImportExportCoordinator(
            dataImporterActor: DataImporterActor(modelContainer: database.container),
            dataExporterActor: DataExporterActor(modelContainer: database.container),
            dataWipeService: dataWipeService,
            bulkClaimBuilderActor: BulkClaimBuilderActor(modelContainer: database.container),
            modelContainer: database.container
        )
        _importExportCoordinator = coordinator
        return coordinator
    }

    public var travelChargeAutomationActor: TravelChargeAutomationActor {
        if let actor = _travelChargeAutomationActor { return actor }
        let actor = TravelChargeAutomationActor(modelContainer: database.container)
        _travelChargeAutomationActor = actor
        return actor
    }
}

public struct SettingsServicesKey: EnvironmentKey {
    public static let defaultValue: SettingsServices? = nil
}

public extension EnvironmentValues {
    var settingsServices: SettingsServices? {
        get { self[SettingsServicesKey.self] }
        set { self[SettingsServicesKey.self] = newValue }
    }
}
