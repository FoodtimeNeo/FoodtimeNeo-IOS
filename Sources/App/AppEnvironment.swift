import Foundation

@MainActor
struct AppEnvironment {
    let baseURL: URL
    let api: APIClient
    let auth: AuthService
    let catalog: CatalogService
    let social: SocialService
    let feedback: FeedbackService
    let reviews: ReviewService
    let venueReviews: VenueReviewService
    let submissions: SubmissionService
    let community: CommunityService
    let drafts: CommunityDraftStore
    let favorites: FavoriteService
    let inbox: InboxService
    let messages: MessageService
    let notifications: NotificationService
    let cookieJar: SystemCookieJar
    let archive: KeychainCookieArchive

    static func live() -> AppEnvironment {
        let baseURL = AppConfiguration.baseURL
        let jar = SystemCookieJar()
        let archive = KeychainCookieArchive()
        let marker = InstallationMarker()

        if marker.consumeFirstLaunch() {
            // Keychain items survive app deletion; never resurrect a session
            // from a previous installation.
            archive.clearAll()
        } else {
            for cookie in archive.load(origin: baseURL) {
                jar.setCookie(cookie)
            }
        }

        let transport = URLSessionTransport(
            requestTimeout: AppConfiguration.requestTimeout,
            resourceTimeout: AppConfiguration.resourceTimeout
        )
        let api = APIClient(baseURL: baseURL, transport: transport, cookieJar: jar)
        api.onCookiesChanged = { [weak jar, weak archive] cookies in
            guard let jar, let archive else { return }
            _ = jar
            archive.save(cookies: cookies, origin: baseURL)
        }

        return AppEnvironment(
            baseURL: baseURL,
            api: api,
            auth: RemoteAuthService(api: api),
            catalog: RemoteCatalogService(api: api, baseURL: baseURL),
            social: RemoteSocialService(api: api),
            feedback: RemoteFeedbackService(api: api),
            reviews: RemoteReviewService(api: api),
            venueReviews: RemoteVenueReviewService(api: api),
            submissions: RemoteSubmissionService(api: api),
            community: RemoteCommunityService(api: api),
            drafts: FileCommunityDraftStore(),
            favorites: RemoteFavoriteService(api: api),
            inbox: RemoteInboxService(api: api),
            messages: RemoteMessageService(api: api),
            notifications: RemoteNotificationService(api: api),
            cookieJar: jar,
            archive: archive
        )
    }
}
