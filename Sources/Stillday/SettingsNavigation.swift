import Foundation
import Combine

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page = "phase"
    @Published var selection: UUID?
}
