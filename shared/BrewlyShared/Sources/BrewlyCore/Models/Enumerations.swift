// Enumerations shared by the app, the API and the database.
// Raw values must match the database domains and CHECK constraints
// (see database/migrations).

/// Who can see a piece of content.
public enum Visibility: String, Codable, CaseIterable, Hashable, Sendable {
    case `public`
    case followers
    case `private`
}

public enum RoastLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case light
    case mediumLight = "medium_light"
    case medium
    case mediumDark = "medium_dark"
    case dark
}

/// Grinder-independent grind descriptor, ordered from finest to coarsest.
public enum GrindSize: String, Codable, CaseIterable, Hashable, Sendable {
    case extraFine = "extra_fine"
    case fine
    case mediumFine = "medium_fine"
    case medium
    case mediumCoarse = "medium_coarse"
    case coarse
    case extraCoarse = "extra_coarse"
}

public enum FilterType: String, Codable, CaseIterable, Hashable, Sendable {
    case paper
    case metal
    case cloth
}

public enum BrewStepKind: String, Codable, CaseIterable, Hashable, Sendable {
    case bloom
    case pour
    case stir
    case swirl
    case wait
    case press
    case invert
    case other
}

public enum MethodCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case pourOver = "pour_over"
    case immersion
    case pressure
    case espresso
    case coldBrew = "cold_brew"
    case dripMachine = "drip_machine"
    case other
}

/// How a brew method expresses its ratio.
public enum RatioBasis: String, Codable, CaseIterable, Hashable, Sendable {
    /// Brew water / dose (filter methods).
    case water
    /// Beverage weight / dose (espresso).
    case beverage
}

public enum CoffeeSpecies: String, Codable, CaseIterable, Hashable, Sendable {
    case arabica
    case robusta
    case liberica
}

public enum GrinderKind: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case electric
}

public enum BurrType: String, Codable, CaseIterable, Hashable, Sendable {
    case conical
    case flat
}

/// Top level of the SCA Coffee Taster's Flavor Wheel.
public enum FlavorCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case fruity
    case floral
    case sweet
    case nuttyCocoa = "nutty_cocoa"
    case spices
    case roasted
    case sourFermented = "sour_fermented"
    case greenVegetative = "green_vegetative"
    case other
}

/// What a post shares besides its text and photos.
public enum PostKind: String, Codable, CaseIterable, Hashable, Sendable {
    /// Text, photos or both.
    case text
    /// One of the author's recipes.
    case recipe
    /// One of the author's beans.
    case bean
}

/// Why a member was notified. Raw values match `notifications.kind`.
public enum NotificationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case follow
    case postLike = "post_like"
    case comment
    case commentReply = "comment_reply"
    case recipeSave = "recipe_save"
    /// Someone remixed the member's recipe; the notification links to the remix.
    case recipeFork = "recipe_fork"
}
