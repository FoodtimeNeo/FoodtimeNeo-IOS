import Foundation

@MainActor
struct AppEnvironment {
    let baseURL: URL
    let api: APIClient
    let auth: AuthService
    let catalog: CatalogService
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
            catalog: RemoteCatalogService(api: api),
            cookieJar: jar,
            archive: archive
        )
    }
}
