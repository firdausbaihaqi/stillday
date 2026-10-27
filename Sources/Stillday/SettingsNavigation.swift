import Foundation
import Combine

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page = "controls"
    @Published var selection: UUID?
}
