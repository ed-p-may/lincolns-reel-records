import Foundation

struct AppConfiguration: Sendable {
    let supabaseURL: URL
    let supabasePublishableKey: String

    static func live(bundle: Bundle = .main) -> AppConfiguration {
        let host = bundle.object(forInfoDictionaryKey: "SUPABASE_PROJECT_HOST") as? String
        let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String

        guard
            let host,
            host != "unconfigured.supabase.co",
            let url = URL(string: "https://\(host)"),
            let key,
            key != "unconfigured"
        else {
            preconditionFailure("Supabase build settings are missing or invalid.")
        }

        return AppConfiguration(supabaseURL: url, supabasePublishableKey: key)
    }
}
