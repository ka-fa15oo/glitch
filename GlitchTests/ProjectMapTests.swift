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

    @Test func subfolderCountsAsItsProject() {
        let map = ProjectMap(defaults: defaults)
        map.noteSeen("/u/PET/Glitch")
        map.noteSeen("/u/PET")
        map.noteSeen("/u/PET/Glitch-app")
        map.noteSeen("/u/PETS")
        #expect(map.known == ["/u/PET", "/u/PETS"])
        map.setIncluded("/u/PET", false)
        #expect(!map.isIncluded("/u/PET/Glitch/deep"))
        #expect(map.isIncluded("/u/PETS"))
        #expect(map.name(for: "/u/PET/Glitch") == "PET")
    }

    @Test func storedSubfoldersAreFolded() {
        defaults.set(["/u/PET", "/u/PET/Glitch"], forKey: "sentinel.knownProjects")
        #expect(ProjectMap(defaults: defaults).known == ["/u/PET"])
    }

    @Test func sameNameGetsParentFolder() {
        let map = ProjectMap(defaults: defaults)
        map.noteSeen("/u/work/PET")
        map.noteSeen("/u/home/PET")
        #expect(map.name(for: "/u/work/PET") == "PET (work)")
        #expect(map.name(for: "/u/home/PET/x") == "PET (home)")
    }
}
