import Foundation
import SwiftData

struct AppBootstrapFailure {
    let message: String
    let diagnosticDetails: String

    init(error: Error) {
        message = error.localizedDescription
        diagnosticDetails = String(reflecting: error)
    }
}

@MainActor
final class AppBootstrapController: ObservableObject {
    enum State {
        case loading
        case ready(ModelContainer, AppRuntime)
        case failed(AppBootstrapFailure)
    }

    @Published private(set) var state: State = .loading

    private let modelContainerFactory: () throws -> ModelContainer
    private var loadTask: Task<Void, Never>?

    init(
        modelContainerFactory: @escaping () throws -> ModelContainer = {
            try DataService.makeModelContainer()
        }
    ) {
        self.modelContainerFactory = modelContainerFactory
        retry()
    }

    deinit {
        loadTask?.cancel()
    }

    func retry() {
        loadTask?.cancel()
        state = .loading
        loadTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            do {
                let container = try modelContainerFactory()
                state = .ready(
                    container,
                    AppRuntime(modelContainer: container)
                )
            } catch {
                state = .failed(AppBootstrapFailure(error: error))
            }
        }
    }
}
