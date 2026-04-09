import Foundation
import Supabase

// Shared Supabase client — use SupabaseService.client everywhere.
// Credentials are injected via xcconfig -> Info.plist at build time.
enum SupabaseService {
    static let client: SupabaseClient = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !urlString.isEmpty,
            !anonKey.isEmpty
        else {
            fatalError("Supabase URL or anon key missing from Info.plist. Check Secrets.xcconfig.")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
}
