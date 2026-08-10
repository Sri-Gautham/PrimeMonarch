import Foundation

@MainActor
final class RecipeCatalogService {

    static let shared = RecipeCatalogService()

    private(set) var allRecipes: [Recipe] = []

    private init() { load() }

    // MARK: - Query

    func search(_ query: String) -> [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return allRecipes }
        return allRecipes.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    func recipes(for type: MealType, suitableFor styles: [DietaryStyle] = [.noRestrictions]) -> [Recipe] {
        allRecipes.filter { $0.category == type.rawValue && $0.isSuitable(for: styles) }
    }

    // MARK: - Load

    private func load() {
        guard let url  = Bundle.main.url(forResource: "recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        allRecipes = (try? JSONDecoder().decode([Recipe].self, from: data)) ?? []
    }
}
