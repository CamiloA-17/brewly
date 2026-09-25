import BrewlyDomain
import SwiftUI

/// State of data loaded asynchronously by a view model.
public enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(DomainError)

    public var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

extension LoadState: Equatable where Value: Equatable {}

/// Renders a `LoadState`: a spinner, an error with retry, or the content.
public struct AsyncContentView<Value, Content: View>: View {
    private let state: LoadState<Value>
    private let retry: @MainActor () async -> Void
    private let content: (Value) -> Content

    public init(
        _ state: LoadState<Value>,
        retry: @escaping @MainActor () async -> Void,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.retry = retry
        self.content = content
    }

    public var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(error):
            ErrorStateView(error: error, retry: retry)
        case let .loaded(value):
            content(value)
        }
    }
}

/// Full-screen error with a retry button.
public struct ErrorStateView: View {
    private let error: DomainError
    private let retry: @MainActor () async -> Void

    public init(error: DomainError, retry: @escaping @MainActor () async -> Void) {
        self.error = error
        self.retry = retry
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text("Something went wrong", bundle: .module)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
        } description: {
            Text(error.localizedMessage)
        } actions: {
            Button {
                Task { await retry() }
            } label: {
                Text("Try again", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
