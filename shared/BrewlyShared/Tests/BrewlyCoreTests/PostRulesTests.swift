import BrewlyCore
import Testing

@Suite("PostRules")
struct PostRulesTests {
    @Test("The kind follows from what the post shares")
    func kind() {
        #expect(PostRules.kind(sharesRecipe: true, sharesBean: false) == .recipe)
        #expect(PostRules.kind(sharesRecipe: false, sharesBean: true) == .bean)
        #expect(PostRules.kind(sharesRecipe: false, sharesBean: false) == .text)
    }

    @Test("A post needs text, photos or something to share")
    func needsContent() {
        #expect(PostRules.validatePost(body: " ", sharesRecipe: false, sharesBean: false, photoCount: 0).map(\.field) == ["body"])
        #expect(PostRules.validatePost(body: nil, sharesRecipe: false, sharesBean: false, photoCount: 1).isEmpty)
        #expect(PostRules.validatePost(body: nil, sharesRecipe: true, sharesBean: false, photoCount: 0).isEmpty)
    }

    @Test("Limits on text, photos and attachments")
    func limits() {
        let long = String(repeating: "a", count: PostRules.bodyMaxLength + 1)
        #expect(PostRules.validatePost(body: long, sharesRecipe: false, sharesBean: false, photoCount: 0).map(\.kind)
                == [.tooLong(max: PostRules.bodyMaxLength)])
        #expect(PostRules.validatePost(body: "Hi", sharesRecipe: false, sharesBean: false, photoCount: 5).map(\.field)
                == ["mediaIds"])
        #expect(PostRules.validatePost(body: "Hi", sharesRecipe: true, sharesBean: true, photoCount: 0).map(\.field)
                == ["beanId"])
    }

    @Test("Comments need 1 to 1000 characters")
    func comments() {
        #expect(PostRules.validateComment(body: "  ").map(\.kind) == [.required])
        #expect(PostRules.validateComment(body: "Nice").isEmpty)
        #expect(PostRules.validateComment(body: String(repeating: "a", count: 1001)).map(\.kind) == [.tooLong(max: 1000)])
    }
}
