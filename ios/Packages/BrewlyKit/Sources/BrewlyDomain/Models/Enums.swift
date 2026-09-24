import Foundation

/// Quién puede ver un contenido. El orden importa: private < followers < public.
public enum Visibility: String, Codable, CaseIterable, Comparable, Sendable {
    case `private`
    case followers
    case `public`

    private var rank: Int {
        switch self {
        case .private: 0
        case .followers: 1
        case .public: 2
        }
    }

    public static func < (lhs: Visibility, rhs: Visibility) -> Bool { lhs.rank < rhs.rank }

    public var title: String {
        switch self {
        case .private: "Solo yo"
        case .followers: "Seguidores"
        case .public: "Público"
        }
    }

    public var systemImage: String {
        switch self {
        case .private: "lock.fill"
        case .followers: "person.2.fill"
        case .public: "globe"
        }
    }
}

public enum UserRole: String, Codable, CaseIterable, Sendable {
    case barista
    case homeBrewer = "home_brewer"
    case roaster
    case enthusiast

    public var title: String {
        switch self {
        case .barista: "Barista"
        case .homeBrewer: "Barista casero"
        case .roaster: "Tostador"
        case .enthusiast: "Entusiasta"
        }
    }
}

public enum RoastLevel: String, Codable, CaseIterable, Sendable {
    case light
    case mediumLight = "medium_light"
    case medium
    case mediumDark = "medium_dark"
    case dark

    public var title: String {
        switch self {
        case .light: "Claro"
        case .mediumLight: "Medio-claro"
        case .medium: "Medio"
        case .mediumDark: "Medio-oscuro"
        case .dark: "Oscuro"
        }
    }
}

public enum CoffeeProcess: String, Codable, CaseIterable, Sendable {
    case washed
    case natural
    case honey
    case anaerobic
    case carbonicMaceration = "carbonic_maceration"
    case wetHulled = "wet_hulled"
    case experimental
    case other

    public var title: String {
        switch self {
        case .washed: "Lavado"
        case .natural: "Natural"
        case .honey: "Honey"
        case .anaerobic: "Anaeróbico"
        case .carbonicMaceration: "Maceración carbónica"
        case .wetHulled: "Descascarado húmedo"
        case .experimental: "Experimental"
        case .other: "Otro"
        }
    }
}

public enum BrewCategory: String, Codable, CaseIterable, Sendable {
    case espresso
    case pourOver = "pour_over"
    case immersion
    case pressure
    case coldBrew = "cold_brew"
    case siphon
    case other
}

public enum EquipmentType: String, Codable, CaseIterable, Sendable {
    case grinder
    case brewer
    case espressoMachine = "espresso_machine"
    case kettle
    case scale
    case filter
    case other
}

public enum StepKind: String, Codable, CaseIterable, Sendable {
    case bloom, pour, stir, swirl, wait, press, invert, extract, other

    public var title: String {
        switch self {
        case .bloom: "Bloom"
        case .pour: "Vertido"
        case .stir: "Remover"
        case .swirl: "Girar"
        case .wait: "Esperar"
        case .press: "Presionar"
        case .invert: "Invertir"
        case .extract: "Extraer"
        case .other: "Otro"
        }
    }
}

public enum FollowStatus: String, Codable, Sendable {
    case notFollowing = "none"
    case pending
    case accepted
    /// El perfil es el del propio usuario.
    case own = "self"
}

public enum PostKind: String, Codable, CaseIterable, Sendable {
    case recipe, brew, bean, note
}

public enum MediaType: String, Codable, Sendable {
    case image, video
}

public enum NotificationType: String, Codable, Sendable {
    case follow
    case followRequest = "follow_request"
    case followAccepted = "follow_accepted"
    case like, comment, reply, fork
}
