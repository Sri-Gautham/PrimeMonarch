import Foundation

// MARK: - Grocery Item

struct GroceryItem: Identifiable {
    let id: String
    let name: String
    var totalAmount: Double
    let unit: String
    let groceryCategory: String

    var displayAmount: String {
        let rounded = (totalAmount * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) \(unit)"
        }
        return "\(rounded) \(unit)"
    }
}

// MARK: - Grocery Aggregation Engine

enum GroceryAggregationEngine {

    static let categoryOrder = ["produce", "protein", "dairy", "grains", "pantry", "condiments"]

    /// Aggregates ingredients from a list of recipes, grouped by grocery category.
    /// Quantities for the same ingredient name and unit are summed.
    static func aggregate(from recipes: [Recipe]) -> [(category: String, items: [GroceryItem])] {
        var byName: [String: GroceryItem] = [:]

        for recipe in recipes {
            for ingredient in recipe.ingredients {
                let key = ingredient.name.lowercased()
                if var existing = byName[key], existing.unit == ingredient.unit {
                    existing.totalAmount += ingredient.amount
                    byName[key] = existing
                } else {
                    byName[key] = GroceryItem(
                        id: ingredient.id,
                        name: ingredient.name,
                        totalAmount: ingredient.amount,
                        unit: ingredient.unit,
                        groceryCategory: ingredient.groceryCategory
                    )
                }
            }
        }

        // Group by category in a defined display order.
        var grouped: [String: [GroceryItem]] = [:]
        for item in byName.values {
            grouped[item.groceryCategory, default: []].append(item)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.name < $1.name }
        }

        return categoryOrder.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }

    static func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "produce":    return "Fresh Produce"
        case "protein":    return "Meat & Fish"
        case "dairy":      return "Dairy"
        case "grains":     return "Grains & Bread"
        case "pantry":     return "Pantry"
        case "condiments": return "Condiments"
        default:           return category.capitalized
        }
    }
}
