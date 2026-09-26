import BrewlyDomain
import Foundation

// Display names for the shared enumerations, localized through the
// design system's string catalogs (English source, Spanish translation).

public extension GrindSize {
    var localizedName: String {
        switch self {
        case .extraFine: String(localized: "Extra fine", bundle: .module)
        case .fine: String(localized: "Fine", bundle: .module)
        case .mediumFine: String(localized: "Medium-fine", bundle: .module)
        case .medium: String(localized: "Medium", bundle: .module)
        case .mediumCoarse: String(localized: "Medium-coarse", bundle: .module)
        case .coarse: String(localized: "Coarse", bundle: .module)
        case .extraCoarse: String(localized: "Extra coarse", bundle: .module)
        }
    }
}

public extension RoastLevel {
    var localizedName: String {
        switch self {
        case .light: String(localized: "Light", bundle: .module)
        case .mediumLight: String(localized: "Medium-light", bundle: .module)
        case .medium: String(localized: "Medium roast", bundle: .module)
        case .mediumDark: String(localized: "Medium-dark", bundle: .module)
        case .dark: String(localized: "Dark", bundle: .module)
        }
    }
}

public extension FilterType {
    var localizedName: String {
        switch self {
        case .paper: String(localized: "Paper", bundle: .module)
        case .metal: String(localized: "Metal", bundle: .module)
        case .cloth: String(localized: "Cloth", bundle: .module)
        }
    }
}

public extension BrewStepKind {
    var localizedName: String {
        switch self {
        case .bloom: String(localized: "Bloom", bundle: .module)
        case .pour: String(localized: "Pour", bundle: .module)
        case .stir: String(localized: "Stir", bundle: .module)
        case .swirl: String(localized: "Swirl", bundle: .module)
        case .wait: String(localized: "Wait", bundle: .module)
        case .press: String(localized: "Press", bundle: .module)
        case .invert: String(localized: "Invert", bundle: .module)
        case .other: String(localized: "Other", bundle: .module)
        }
    }
}

public extension MethodCategory {
    var localizedName: String {
        switch self {
        case .pourOver: String(localized: "Pour-over", bundle: .module)
        case .immersion: String(localized: "Immersion", bundle: .module)
        case .pressure: String(localized: "Pressure", bundle: .module)
        case .espresso: String(localized: "Espresso", bundle: .module)
        case .coldBrew: String(localized: "Cold brew", bundle: .module)
        case .dripMachine: String(localized: "Drip machine", bundle: .module)
        case .other: String(localized: "Other", bundle: .module)
        }
    }
}

public extension Visibility {
    var localizedName: String {
        switch self {
        case .public: String(localized: "Everyone", bundle: .module)
        case .followers: String(localized: "Followers", bundle: .module)
        case .private: String(localized: "Only me", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .public: "globe"
        case .followers: "person.2"
        case .private: "lock"
        }
    }
}

public extension CoffeeSpecies {
    var localizedName: String {
        switch self {
        case .arabica: String(localized: "Arabica", bundle: .module)
        case .robusta: String(localized: "Robusta", bundle: .module)
        case .liberica: String(localized: "Liberica", bundle: .module)
        }
    }
}

public extension FlavorCategory {
    var localizedName: String {
        switch self {
        case .fruity: String(localized: "Fruity", bundle: .module)
        case .floral: String(localized: "Floral", bundle: .module)
        case .sweet: String(localized: "Sweet", bundle: .module)
        case .nuttyCocoa: String(localized: "Nutty / Cocoa", bundle: .module)
        case .spices: String(localized: "Spices", bundle: .module)
        case .roasted: String(localized: "Roasted", bundle: .module)
        case .sourFermented: String(localized: "Sour / Fermented", bundle: .module)
        case .greenVegetative: String(localized: "Green / Vegetative", bundle: .module)
        case .other: String(localized: "Other", bundle: .module)
        }
    }
}

// MARK: - Catalog items

// Catalog names come from the API in English. Known items are translated through
// dedicated string tables keyed by their English name; unknown ones fall back to it.

public extension EquipmentKind {
    var localizedName: String {
        switch self {
        case .grinder: String(localized: "Grinder", bundle: .module)
        case .brewer: String(localized: "Brewer", bundle: .module)
        case .kettle: String(localized: "Kettle", bundle: .module)
        case .scale: String(localized: "Scale", bundle: .module)
        case .espressoMachine: String(localized: "Espresso machine", bundle: .module)
        case .other: String(localized: "Other equipment", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .grinder: "gearshape.2"
        case .brewer: "cup.and.saucer"
        case .kettle: "drop"
        case .scale: "scalemass"
        case .espressoMachine: "cup.and.heat.waves"
        case .other: "wrench.and.screwdriver"
        }
    }
}

public extension DrinkType {
    var localizedName: String {
        switch self {
        case .espresso: String(localized: "Espresso", bundle: .module)
        case .ristretto: String(localized: "Ristretto", bundle: .module)
        case .lungo: String(localized: "Lungo", bundle: .module)
        case .americano: String(localized: "Americano", bundle: .module)
        case .cortado: String(localized: "Cortado", bundle: .module)
        case .flatWhite: String(localized: "Flat white", bundle: .module)
        case .cappuccino: String(localized: "Cappuccino", bundle: .module)
        case .latte: String(localized: "Latte", bundle: .module)
        case .macchiato: String(localized: "Macchiato", bundle: .module)
        case .mocha: String(localized: "Mocha", bundle: .module)
        case .other: String(localized: "Other drink", bundle: .module)
        }
    }
}

public extension Tasting.Attribute {
    var localizedName: String {
        switch self {
        case .acidity: String(localized: "Acidity", bundle: .module)
        case .sweetness: String(localized: "Sweetness", bundle: .module)
        case .body: String(localized: "Body", bundle: .module)
        case .bitterness: String(localized: "Bitterness", bundle: .module)
        case .aftertaste: String(localized: "Aftertaste", bundle: .module)
        }
    }
}

public extension BrewMethod {
    var localizedName: String {
        Bundle.module.localizedString(forKey: name, value: name, table: "CatalogMethods")
    }
}

public extension ProcessingMethod {
    var localizedName: String {
        Bundle.module.localizedString(forKey: name, value: name, table: "CatalogProcesses")
    }
}

public extension FlavorNote {
    var localizedName: String {
        Bundle.module.localizedString(forKey: name, value: name, table: "CatalogFlavorNotes")
    }
}

public extension Country {
    /// The country name in the user's language, from its ISO code.
    var localizedName: String {
        Locale.current.localizedString(forRegionCode: code) ?? name
    }
}

// MARK: - Errors

public extension RuleViolation {
    var localizedMessage: String {
        switch kind {
        case .required:
            return String(localized: "This field is required.", bundle: .module)
        case let .outOfRange(min, max):
            let lower = RuleViolation.format(min)
            let upper = RuleViolation.format(max)
            return String(localized: "Must be between \(lower) and \(upper).", bundle: .module)
        case let .tooLong(max):
            return String(localized: "Must be at most \(max) characters.", bundle: .module)
        case .invalidFormat:
            return String(localized: "The format is not valid.", bundle: .module)
        case .notAllowed:
            return String(localized: "Not allowed for this brew method.", bundle: .module)
        case .exceeds:
            return String(localized: "Is greater than the related value.", bundle: .module)
        case .inFuture:
            return String(localized: "Can't be in the future.", bundle: .module)
        case let .tooMany(max):
            return String(localized: "Must have at most \(max) items.", bundle: .module)
        case let .tooYoung(minimumAge):
            return String(localized: "You must be at least \(minimumAge) years old.", bundle: .module)
        case .before:
            return String(localized: "Is earlier than the related date.", bundle: .module)
        }
    }
}

public extension Array where Element == RuleViolation {
    /// The message of the first violation for `field`, if any.
    func message(for field: String) -> String? {
        first { $0.field == field }?.localizedMessage
    }
}

public extension DomainError {
    var localizedMessage: String {
        switch self {
        case .validation:
            String(localized: "Please review the highlighted fields.", bundle: .module)
        case .notFound:
            String(localized: "We couldn't find what you were looking for.", bundle: .module)
        case let .conflict(code) where code == "bean_in_use":
            String(localized: "This bean is used by recipes or brews. Archive it instead.", bundle: .module)
        case let .conflict(code) where code == "username_taken":
            String(localized: "That username is already taken.", bundle: .module)
        case let .conflict(code) where code == "email_taken":
            String(localized: "An account with that email already exists.", bundle: .module)
        case .conflict:
            String(localized: "This action conflicts with existing data.", bundle: .module)
        case .invalidCredentials:
            String(localized: "Invalid email or password.", bundle: .module)
        case .unauthorized:
            String(localized: "Your session has expired. Please sign in again.", bundle: .module)
        case .offline:
            String(localized: "Can't reach Brewly. Check your connection.", bundle: .module)
        case .unexpected:
            String(localized: "Something unexpected happened. Please try again.", bundle: .module)
        }
    }
}

public extension Error {
    /// A user-facing message for any error.
    var brewlyMessage: String {
        (self as? DomainError)?.localizedMessage
            ?? String(localized: "Something unexpected happened. Please try again.", bundle: .module)
    }
}
