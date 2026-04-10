import Foundation
import Supabase

// Shared Supabase client — use SupabaseService.client everywhere.
// The anon key is a public JWT safe for client-side use.
enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://uupftsuexunuwsdejxrh.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1cGZ0c3VleHVudXdzZGVqeHJoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NDk4MTQsImV4cCI6MjA5MTMyNTgxNH0.8mGjFrMj2bqyZuyrQIDcBsYlp7uXITLMyWSXqj-thQ8"
    )
}
