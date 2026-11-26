import Foundation
import Supabase

/// The link to Supabase: the word catalogue, a silent anonymous account, and
/// the backup of the member's data. Every call fails quietly, because the app
/// must keep working offline with the bundled catalogue and the local store.
final class Backend {
    static let shared = Backend()

    // The publishable key is meant to ship in the app; row-level security does the guarding.
    private static let projectURL = URL(string: "https://ybufanypeamzxnsqsvzf.supabase.co")!
    private static let publishableKey = "sb_publishable_twI_ctVHUTvuE6u76mRbbA_yJQ73WTS"

    let client = SupabaseClient(supabaseURL: Backend.projectURL, supabaseKey: Backend.publishableKey)

    private(set) var signedIn = false
    private var pending: Task<Void, Never>?

    private init() {}

    /// Where the last downloaded catalogue is kept. Read at the next launch.
    static var catalogCacheURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("catalog.json")
    }

    func start() {
        Task {
            await refreshCatalog()
            await signIn()
            await firstSync()
        }
    }

    /// Download the published words and keep them for the next launch.
    private func refreshCatalog() async {
        do {
            let data = try await client.from("catalog").select().execute().data
            let words = try JSONDecoder().decode([Word].self, from: data)
            guard !words.isEmpty else { return }
            let url = Backend.catalogCacheURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            // Offline, or the project is unreachable: keep what we have.
        }
    }

    /// An anonymous account, so data can be backed up before the member signs in
    /// with Apple or Google. Needs "Anonymous sign-ins" enabled in the project.
    private func signIn() async {
        if client.auth.currentSession != nil {
            signedIn = true
            return
        }
        do {
            try await client.auth.signInAnonymously()
            signedIn = true
        } catch {
            signedIn = false
        }
    }

    /// A fresh install takes the server's copy; otherwise the device wins.
    private func firstSync() async {
        guard signedIn else { return }
        do {
            let remote: UserState = try await client.rpc("get_user_state").execute().value
            let local = await MainActor.run { UserStore.shared.snapshot() }
            if local.isEmpty && !remote.isEmpty {
                await MainActor.run { UserStore.shared.adopt(remote) }
            } else {
                await push()
            }
        } catch {
            // Try again at the next change.
        }
    }

    /// Called after every local change. Waits two seconds so a burst of changes is one request.
    func scheduleSync() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }
            await push()
        }
    }

    private func push() async {
        guard signedIn else { return }
        let snapshot = await MainActor.run { UserStore.shared.snapshot() }
        do {
            try await client.rpc("sync_user_state", params: SyncParameters(state: snapshot)).execute()
        } catch {
            // Kept locally; the next change retries.
        }
    }
}

private struct SyncParameters: Encodable {
    let state: UserState
}
