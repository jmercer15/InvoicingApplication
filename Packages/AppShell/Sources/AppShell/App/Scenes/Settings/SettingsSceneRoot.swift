import SwiftUI

struct SettingsSceneRoot: View {
    let runtime: AppRuntime
    @State private var appDependencies: AppDependencies

    init(runtime: AppRuntime) {
        self.runtime = runtime
        _appDependencies = State(initialValue: AppDependencies(runtime: runtime))
    }

    var body: some View {
        NativeSettingsRootView()
            .withSettingsDependencies(appDependencies)
    }
}
