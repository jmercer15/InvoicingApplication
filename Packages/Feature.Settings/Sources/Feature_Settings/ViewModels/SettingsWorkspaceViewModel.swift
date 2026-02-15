import Data
import Combine

@MainActor
public final class SettingsWorkspaceViewModel: ObservableObject {
    @Published var selectedSection: SettingsView.SettingsSection? = nil
    @Published var displayedSection: SettingsView.SettingsSection? = nil
    @Published var isTransitioning: Bool = false
    
    public let unitOfWork: UnitOfWorkService
    public let dataImporterActor: DataImporterActor
    public let dataExporterActor: DataExporterActor

    public init(
        unitOfWork: UnitOfWorkService,
        dataImporterActor: DataImporterActor,
        dataExporterActor: DataExporterActor
    ) {
        self.unitOfWork = unitOfWork
        self.dataImporterActor = dataImporterActor
        self.dataExporterActor = dataExporterActor
    }
}
