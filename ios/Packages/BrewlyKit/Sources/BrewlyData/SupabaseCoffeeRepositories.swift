import BrewlyDomain
import Foundation
import Supabase

struct SupabaseCoffeeRepository: CoffeeRepository {
    let client: SupabaseClient

    func beans(includeArchived: Bool) async throws -> [CoffeeBean] {
        let id = try client.requireUserID()
        var query = client.from("coffee_beans").select().eq("owner_id", value: id)
        if !includeArchived {
            query = query.is("archived_at", value: nil)
        }
        return try await query.order("created_at", ascending: false).execute().value
    }

    func saveBean(_ bean: CoffeeBean) async throws -> CoffeeBean {
        try await client.from("coffee_beans")
            .upsert(bean, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }

    func deleteBean(id: UUID) async throws {
        try await client.from("coffee_beans").delete().eq("id", value: id).execute()
    }

    func bags(beanID: UUID?) async throws -> [BeanBag] {
        let owner = try client.requireUserID()
        var query = client.from("bean_bags").select().eq("owner_id", value: owner)
        if let beanID {
            query = query.eq("bean_id", value: beanID)
        }
        return try await query.order("created_at", ascending: false).execute().value
    }

    func saveBag(_ bag: BeanBag) async throws -> BeanBag {
        try await client.from("bean_bags")
            .upsert(bag, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }

    func deleteBag(id: UUID) async throws {
        try await client.from("bean_bags").delete().eq("id", value: id).execute()
    }

    func equipment() async throws -> [Equipment] {
        let owner = try client.requireUserID()
        return try await client.from("equipment")
            .select()
            .eq("owner_id", value: owner)
            .is("archived_at", value: nil)
            .order("type")
            .execute()
            .value
    }

    func saveEquipment(_ item: Equipment) async throws -> Equipment {
        try await client.from("equipment")
            .upsert(item, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }

    func brewMethods() async throws -> [BrewMethod] {
        // RLS ya limita a los métodos del sistema + los propios.
        try await client.from("brew_methods")
            .select()
            .order("category")
            .order("name")
            .execute()
            .value
    }
}

struct SupabaseRecipeRepository: RecipeRepository {
    let client: SupabaseClient

    func myRecipes() async throws -> [Recipe] {
        let owner = try client.requireUserID()
        return try await client.from("recipes")
            .select(Select.recipe)
            .eq("owner_id", value: owner)
            .is("archived_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func recipe(id: UUID) async throws -> Recipe {
        try await client.from("recipes")
            .select(Select.recipe)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func save(_ recipe: Recipe) async throws -> Recipe {
        try await client.from("recipes").upsert(recipe, onConflict: "id").execute()

        struct StepsParams: Encodable {
            let p_recipe_id: UUID
            let p_steps: [RecipeStep]
        }
        try await client
            .rpc("replace_recipe_steps", params: StepsParams(p_recipe_id: recipe.id, p_steps: recipe.steps))
            .execute()

        return try await self.recipe(id: recipe.id)
    }

    func delete(id: UUID) async throws {
        try await client.from("recipes").delete().eq("id", value: id).execute()
    }

    func fork(id: UUID) async throws -> Recipe {
        struct Params: Encodable { let p_recipe_id: UUID }
        let newID: UUID = try await client.rpc("fork_recipe", params: Params(p_recipe_id: id))
            .execute()
            .value
        return try await recipe(id: newID)
    }
}

struct SupabaseBrewRepository: BrewRepository {
    let client: SupabaseClient

    func myBrews(limit: Int) async throws -> [Brew] {
        let owner = try client.requireUserID()
        return try await client.from("brews")
            .select()
            .eq("owner_id", value: owner)
            .order("brewed_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func save(_ brew: Brew) async throws -> Brew {
        try await client.from("brews")
            .upsert(brew, onConflict: "id")
            .select()
            .single()
            .execute()
            .value
    }

    func delete(id: UUID) async throws {
        try await client.from("brews").delete().eq("id", value: id).execute()
    }

    func stats(days: Int) async throws -> BrewStats {
        struct Params: Encodable { let p_days: Int }
        let rows: [BrewStats] = try await client.rpc("my_brew_stats", params: Params(p_days: days))
            .execute()
            .value
        return rows.first ?? BrewStats()
    }
}
