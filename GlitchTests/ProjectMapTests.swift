import Foundation
import Testing

@MainActor
struct ProjectMapTests {
    let suite = UUID().uuidString
    var defaults: UserDefaults { UserDefaults(suiteName: suite)! }

    @Test func defaultNameIsLastComponent() {
        #expect(ProjectMap(defaults: defaults).name(for: "/Users/x/Documents/PET") == "PET")
    }

    @Test func renameOverrides() {
        let map = ProjectMap(defaults: defaults)
        map.rename("/Users/x/PET", to: "ICON")
        #expect(map.name(for: "/Users/x/PET") == "ICON")
    }

    @Test func includedByDefault() { #expect(ProjectMap(defaults: defaults).isIncluded("/a")) }

    @Test func exclusionPersists() {
        ProjectMap(defaults: defaults).setIncluded("/a", false)
        let again = ProjectMap(defaults: defaults)
        #expect(!again.isIncluded("/a"))
        again.setIncluded("/a", true)
        #expect(ProjectMap(defaults: defaults).isIncluded("/a"))
    }

    @Test func knownPersists() {
        let map = ProjectMap(defaults: defaults)
        map.noteSeen("/a")
        map.noteSeen("/a")
        map.noteSeen("/b")
        #expect(ProjectMap(defaults: defaults).known == ["/a", "/b"])
    }
}
