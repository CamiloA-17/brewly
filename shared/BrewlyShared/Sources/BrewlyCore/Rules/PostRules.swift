/// Validation rules for posts and comments. Limits mirror the `posts`, `post_media` and `comments` tables.
public enum PostRules {
    public static let bodyMaxLength = 2000
    public static let maxPhotos = 4
    public static let commentMaxLength = 1000

    /// The kind follows from what the post shares.
    public static func kind(sharesRecipe: Bool, sharesBean: Bool) -> PostKind {
        if sharesRecipe { return .recipe }
        if sharesBean { return .bean }
        return .text
    }

    /// A post needs text, photos or something to share, and shares at most one recipe or bean.
    public static func validatePost(body: String?, sharesRecipe: Bool, sharesBean: Bool, photoCount: Int) -> [RuleViolation] {
        var check = ViolationCollector()
        let text = body?.trimmingWhitespace ?? ""
        if text.count > bodyMaxLength {
            check.add("body", .tooLong(max: bodyMaxLength))
        }
        if sharesRecipe && sharesBean {
            check.add("beanId", .notAllowed)
        }
        if photoCount > maxPhotos {
            check.add("mediaIds", .tooMany(max: maxPhotos))
        }
        if text.isEmpty && photoCount == 0 && !sharesRecipe && !sharesBean {
            check.add("body", .required)
        }
        return check.violations
    }

    public static func validateComment(body: String) -> [RuleViolation] {
        var check = ViolationCollector()
        check.requireText(body, field: "body", maxLength: commentMaxLength)
        return check.violations
    }
}
