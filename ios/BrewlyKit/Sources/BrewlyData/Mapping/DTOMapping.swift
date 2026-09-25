import BrewlyAPI
import BrewlyDomain
import Foundation

// MARK: - API → Domain

extension UserProfile {
    init(_ dto: CurrentUserDTO) {
        self.init(
            id: dto.id,
            username: dto.username,
            displayName: dto.displayName,
            email: dto.email,
            bio: dto.bio,
            avatarURL: dto.avatarURL.flatMap(URL.init(string:)),
            location: dto.location,
            createdAt: dto.createdAt
        )
    }
}

extension UserSummary {
    init(_ dto: UserSummaryDTO) {
        self.init(id: dto.id, username: dto.username, displayName: dto.displayName, avatarURL: dto.avatarURL.flatMap(URL.init(string:)))
    }
}

extension Catalog {
    init(_ dto: CatalogDTO) {
        self.init(
            brewMethods: dto.brewMethods.map {
                BrewMethod(
                    slug: $0.slug, name: $0.name, category: $0.category, ratioBasis: $0.ratioBasis,
                    description: $0.description, defaultRatio: $0.defaultRatio,
                    defaultGrindSize: $0.defaultGrindSize, defaultWaterTempC: $0.defaultWaterTempC
                )
            },
            varietals: dto.varietals.map { Varietal(slug: $0.slug, name: $0.name, species: $0.species) },
            processingMethods: dto.processingMethods.map {
                ProcessingMethod(slug: $0.slug, name: $0.name, description: $0.description)
            },
            countries: dto.countries.map { Country(code: $0.code, name: $0.name) },
            grinders: dto.grinders.map {
                Grinder(slug: $0.slug, brand: $0.brand, model: $0.model, kind: $0.kind, burrType: $0.burrType)
            },
            flavorNotes: dto.flavorNotes.map { FlavorNote(slug: $0.slug, name: $0.name, category: $0.category) }
        )
    }
}

extension Bean {
    init(_ dto: BeanDTO) {
        self.init(
            id: dto.id,
            ownerID: dto.ownerId,
            name: dto.name,
            roaster: dto.roaster,
            countryCode: dto.countryCode,
            region: dto.region,
            farm: dto.farm,
            producer: dto.producer,
            altitudeMinM: dto.altitudeMinM,
            altitudeMaxM: dto.altitudeMaxM,
            processingMethodSlug: dto.processingMethodSlug,
            varietalSlugs: dto.varietalSlugs,
            flavorNoteSlugs: dto.flavorNoteSlugs,
            roastLevel: dto.roastLevel,
            roastDate: dto.roastDate,
            harvestYear: dto.harvestYear,
            scaScore: dto.scaScore,
            weightG: dto.weightG,
            isDecaf: dto.isDecaf,
            notes: dto.notes,
            photoURL: dto.photoURL.flatMap(URL.init(string:)),
            visibility: dto.visibility,
            isArchived: dto.isArchived,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
}

extension Recipe {
    init(_ dto: RecipeDTO) {
        self.init(
            id: dto.id,
            author: UserSummary(dto.author),
            bean: BeanSummary(dto.bean),
            methodSlug: dto.methodSlug,
            forkedFromID: dto.forkedFromId,
            forkedFrom: dto.forkedFrom.map {
                RecipeReference(id: $0.id, title: $0.title, author: UserSummary($0.author))
            },
            title: dto.title,
            description: dto.description,
            doseG: dto.doseG,
            waterG: dto.waterG,
            yieldG: dto.yieldG,
            ratio: dto.ratio,
            grindSize: dto.grindSize,
            grinderSlug: dto.grinderSlug,
            grindSetting: dto.grindSetting,
            grindMicrons: dto.grindMicrons,
            waterTempC: dto.waterTempC,
            bloomWaterG: dto.bloomWaterG,
            bloomTimeS: dto.bloomTimeS,
            totalTimeS: dto.totalTimeS,
            pressureBar: dto.pressureBar,
            filterType: dto.filterType,
            waterProfile: dto.waterProfile,
            waterTdsPpm: dto.waterTdsPpm,
            tdsPercent: dto.tdsPercent,
            extractionYieldPercent: dto.extractionYieldPercent,
            rating: dto.rating,
            notes: dto.notes,
            flavorNoteSlugs: dto.flavorNoteSlugs,
            steps: dto.steps.map {
                RecipeStep(position: $0.position, kind: $0.kind, startS: $0.startS,
                           waterTargetG: $0.waterTargetG, instruction: $0.instruction)
            },
            visibility: dto.visibility,
            saveCount: dto.saveCount,
            forkCount: dto.forkCount,
            isSaved: dto.isSaved,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
}

extension MediaItem {
    init?(_ dto: MediaDTO) {
        guard let url = URL(string: dto.url) else { return nil }
        self.init(id: dto.id, url: url, width: dto.width, height: dto.height)
    }
}

extension BeanSummary {
    init(_ dto: BeanSummaryDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            roaster: dto.roaster,
            countryCode: dto.countryCode,
            farm: dto.farm,
            processingMethodSlug: dto.processingMethodSlug,
            varietalSlugs: dto.varietalSlugs,
            roastLevel: dto.roastLevel
        )
    }
}

extension Post {
    init(_ dto: PostDTO) {
        self.init(
            id: dto.id,
            author: UserSummary(dto.author),
            kind: dto.kind,
            body: dto.body,
            recipe: dto.recipe.map(RecipeSummary.init),
            bean: dto.bean.map(BeanSummary.init),
            media: dto.media.compactMap(MediaItem.init),
            visibility: dto.visibility,
            likeCount: dto.likeCount,
            commentCount: dto.commentCount,
            isLiked: dto.isLiked,
            createdAt: dto.createdAt
        )
    }
}

extension LikeState {
    init(_ dto: LikeStateDTO) {
        self.init(isLiked: dto.isLiked, likeCount: dto.likeCount)
    }
}

extension Comment {
    init(_ dto: CommentDTO) {
        self.init(
            id: dto.id,
            postID: dto.postId,
            parentID: dto.parentId,
            author: UserSummary(dto.author),
            body: dto.body,
            canDelete: dto.canDelete,
            createdAt: dto.createdAt
        )
    }
}

extension SaveState {
    init(_ dto: SaveStateDTO) {
        self.init(isSaved: dto.isSaved, saveCount: dto.saveCount)
    }
}

extension MemberProfile {
    init(_ dto: UserProfileDTO) {
        self.init(
            id: dto.id,
            username: dto.username,
            displayName: dto.displayName,
            bio: dto.bio,
            avatarURL: dto.avatarURL.flatMap(URL.init(string:)),
            location: dto.location,
            createdAt: dto.createdAt,
            followerCount: dto.followerCount,
            followingCount: dto.followingCount,
            recipeCount: dto.recipeCount,
            isFollowing: dto.isFollowing,
            followsYou: dto.followsYou,
            isMe: dto.isMe
        )
    }
}

extension FollowState {
    init(_ dto: FollowStateDTO) {
        self.init(isFollowing: dto.isFollowing, followerCount: dto.followerCount)
    }
}

extension RecipeSummary {
    init(_ dto: RecipeSummaryDTO) {
        self.init(
            id: dto.id,
            author: UserSummary(dto.author),
            beanName: dto.beanName,
            methodSlug: dto.methodSlug,
            title: dto.title,
            doseG: dto.doseG,
            ratio: dto.ratio,
            grindSize: dto.grindSize,
            waterTempC: dto.waterTempC,
            totalTimeS: dto.totalTimeS,
            rating: dto.rating,
            visibility: dto.visibility,
            createdAt: dto.createdAt
        )
    }
}

// MARK: - Domain → API

extension UpsertBeanRequest {
    init(_ draft: BeanDraft) {
        self.init(
            name: draft.name.trimmingWhitespace,
            roaster: draft.roaster.nilIfBlank,
            countryCode: draft.countryCode,
            region: draft.region.nilIfBlank,
            farm: draft.farm.nilIfBlank,
            producer: draft.producer.nilIfBlank,
            altitudeMinM: draft.altitudeMinM,
            altitudeMaxM: draft.altitudeMaxM,
            processingMethodSlug: draft.processingMethodSlug,
            varietalSlugs: draft.varietalSlugs.sorted(),
            flavorNoteSlugs: draft.flavorNoteSlugs.sorted(),
            roastLevel: draft.roastLevel,
            roastDate: draft.roastDate,
            harvestYear: draft.harvestYear,
            scaScore: draft.scaScore,
            weightG: draft.weightG,
            isDecaf: draft.isDecaf,
            notes: draft.notes.nilIfBlank,
            visibility: draft.visibility,
            isArchived: draft.isArchived
        )
    }
}

extension UpsertRecipeRequest {
    init(_ input: RecipeInput) {
        let draft = input.draft
        self.init(
            beanId: input.beanID,
            forkedFromId: draft.forkedFromID,
            methodSlug: input.methodSlug,
            title: draft.title.trimmingWhitespace,
            description: draft.description.nilIfBlank,
            doseG: draft.doseG ?? 0,
            waterG: draft.waterG,
            yieldG: draft.yieldG,
            grindSize: draft.grindSize,
            grinderSlug: draft.grinderSlug,
            grindSetting: draft.grindSetting.nilIfBlank,
            grindMicrons: draft.grindMicrons,
            waterTempC: draft.waterTempC,
            bloomWaterG: draft.bloomWaterG,
            bloomTimeS: draft.bloomTimeS,
            totalTimeS: draft.totalTimeS,
            pressureBar: draft.pressureBar,
            filterType: draft.filterType,
            waterProfile: draft.waterProfile.nilIfBlank,
            waterTdsPpm: draft.waterTdsPpm,
            tdsPercent: draft.tdsPercent,
            rating: draft.rating,
            notes: draft.notes.nilIfBlank,
            flavorNoteSlugs: draft.flavorNoteSlugs.sorted(),
            steps: draft.steps.map {
                RecipeStepInput(kind: $0.kind, startS: $0.startS, waterTargetG: $0.waterTargetG,
                                instruction: $0.instruction.nilIfBlank)
            },
            visibility: draft.visibility
        )
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingWhitespace
        return trimmed.isEmpty ? nil : trimmed
    }
}
