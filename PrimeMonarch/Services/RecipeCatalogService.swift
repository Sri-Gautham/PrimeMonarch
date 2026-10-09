import Foundation

@MainActor
final class RecipeCatalogService {

    static let shared = RecipeCatalogService()

    private(set) var allRecipes: [Recipe] = []

    private init() { load() }

    // MARK: - Query

    /// Returns all recipes whose names match the query, excluding any recipes that
    /// contain a term from `avoiding` (user allergies / foods-to-avoid).
    func search(_ query: String, avoiding terms: [String] = []) -> [Recipe] {
        let q    = query.trimmingCharacters(in: .whitespaces)
        let pool = terms.isEmpty ? allRecipes : allRecipes.filter { !$0.contains(anyOf: terms) }
        guard !q.isEmpty else { return pool }
        return pool.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    /// Returns recipes for the given meal type that satisfy the dietary styles,
    /// hard-excluding any recipe that contains a term from `avoiding`.
    func recipes(
        for type: MealType,
        suitableFor styles: [DietaryStyle] = [.noRestrictions],
        avoiding terms: [String] = []
    ) -> [Recipe] {
        let pool = terms.isEmpty ? allRecipes : allRecipes.filter { !$0.contains(anyOf: terms) }
        return pool.filter { $0.category == type.rawValue && $0.isSuitable(for: styles) }
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
