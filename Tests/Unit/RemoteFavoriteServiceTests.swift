import XCTest
@testable import FoodtimeNeo

final class RemoteFavoriteServiceTests: XCTestCase {
    func testGroupsCreateUpdateDeleteAndMembership() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            [{"id":"g-1","kind":"dish","name":"默认","sortOrder":0,"revision":1,"itemCount":2}]
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-f1"}
            """)),
            .init(status: 201, body: TestFixtures.envelope("""
            {"id":"g-2","kind":"dish","name":"新分组","sortOrder":1,"revision":1,"itemCount":0}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"id":"g-2","kind":"dish","name":"改名","sortOrder":1,"revision":2,"itemCount":0}
            """)),
            .init(status: 204, body: ""),
            .init(status: 200, body: TestFixtures.envelope("""
            {"groupIds":["g-1"]}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"groupIds":["g-1","g-2"]}
            """))
        ]
        let service = RemoteFavoriteService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let groups = try await service.groups(kind: .dish)
        let created = try await service.createGroup(kind: .dish, name: "新分组", sortOrder: 1)
        let renamed = try await service.updateGroup(
            id: "g-2",
            name: "改名",
            sortOrder: 1,
            expectedRevision: 1
        )
        try await service.deleteGroup(id: "g-2")
        let membership = try await service.memberships(kind: .dish, targetID: "d-1")
        let added = try await service.addMember(groupID: "g-2", targetID: "d-1")

        XCTAssertEqual(groups.first?.name, "默认")
        XCTAssertEqual(created.id, "g-2")
        XCTAssertEqual(renamed.name, "改名")
        XCTAssertEqual(membership, ["g-1"])
        XCTAssertEqual(added, ["g-1", "g-2"])
        XCTAssertEqual(transport.requests[0].url?.path, "/api/v1/users/me/favorite-groups")
        XCTAssertEqual(transport.requests[4].httpMethod, "DELETE")
        XCTAssertEqual(transport.requests[5].url?.path, "/api/v1/users/me/favorite-groups/memberships")
    }

    func testFavoritesListsAndDishToggle() async throws {
        let transport = StubHTTPTransport()
        transport.replies = [
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[],"total":0,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"items":[],"total":0,"page":1,"size":20}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"saved":true}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"headerName":"X-CSRF-TOKEN","token":"token-f2"}
            """)),
            .init(status: 200, body: TestFixtures.envelope("""
            {"saved":true}
            """))
        ]
        let service = RemoteFavoriteService(
            api: TestFixtures.makeClient(transport: transport, jar: MemoryCookieJar())
        )

        let dishes = try await service.dishFavorites(
            groupID: "g-1",
            unfiled: false,
            page: 1,
            size: 20
        )
        let posts = try await service.communityFavorites(
            groupID: nil,
            unfiled: true,
            page: 1,
            size: 20
        )
        let state = try await service.dishFavoriteState(dishID: "d-1")
        let saved = try await service.setDishFavorite(dishID: "d-1", favorited: true)

        XCTAssertEqual(dishes.total, 0)
        XCTAssertEqual(posts.total, 0)
        XCTAssertTrue(state)
        XCTAssertTrue(saved)
        let dishQuery = URLComponents(
            url: try XCTUnwrap(transport.requests[0].url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(dishQuery?.first(where: { $0.name == "groupId" })?.value, "g-1")
        let postQuery = URLComponents(
            url: try XCTUnwrap(transport.requests[1].url),
            resolvingAgainstBaseURL: false
        )?.queryItems
        XCTAssertEqual(postQuery?.first(where: { $0.name == "unfiled" })?.value, "true")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/v1/users/me/dish-favorites/d-1")
    }
}
