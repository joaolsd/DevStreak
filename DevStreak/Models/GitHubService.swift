import Foundation

/// Lightweight GitHub API client.
/// Uses the public Events API for public repos (no auth needed),
/// or the authenticated API for private repos via a personal access token.
actor GitHubService {

    static let shared = GitHubService()
    private init() {}

    // MARK: – Types

    struct CommitSummary {
        let repo: String
        let sha: String
        let message: String
        let additions: Int
        let deletions: Int
        let filesChanged: Int

        var isTrivial: Bool {
            let netLines = additions + deletions
            let tooSmall = netLines < AppConstants.githubMinNetLines
                        && filesChanged < AppConstants.githubMinFiles
            let emptyMessage = message.trimmingCharacters(in: .whitespaces).isEmpty
            let boilerplate = ["wip", ".", "test", "temp", "tmp", "fix"]
                .contains(message.lowercased().trimmingCharacters(in: .whitespaces))
            return tooSmall || emptyMessage || boilerplate
        }
    }

    enum VerificationResult {
        case verified(commits: [CommitSummary])   // ≥1 non-trivial commit today
        case onlyTrivial(commits: [CommitSummary]) // commits found but all trivial
        case noCommitsToday
        case networkError(String)
        case notConfigured
    }

    // MARK: – Public API

    /// Check whether the user has a qualifying commit today.
    func verifyToday(username: String, token: String?) async -> VerificationResult {
        guard !username.isEmpty else { return .notConfigured }

        // 1. Fetch recent push events
        guard let events = await fetchPushEvents(username: username, token: token) else {
            return .networkError("Could not reach GitHub API")
        }

        // 2. Filter to today's commits
        let todayKey = DateHelpers.todayKey()
        let todayCommits = events.filter { $0.dateKey == todayKey }

        guard !todayCommits.isEmpty else { return .noCommitsToday }

        // 3. Fetch diff stats for each commit (up to 5 to avoid hammering the API)
        var summaries: [CommitSummary] = []
        for event in todayCommits.prefix(5) {
            if let summary = await fetchCommitDetail(
                owner: event.owner, repo: event.repo,
                sha: event.sha, token: token
            ) {
                summaries.append(summary)
            }
        }

        // 4. Check for at least one non-trivial commit
        let nonTrivial = summaries.filter { !$0.isTrivial }
        if nonTrivial.isEmpty {
            return summaries.isEmpty ? .noCommitsToday : .onlyTrivial(commits: summaries)
        }
        return .verified(commits: nonTrivial)
    }

    // MARK: – Private: Events

    private struct PushEventCommit {
        let owner: String
        let repo: String
        let sha: String
        let message: String
        let dateKey: String
    }

    private func fetchPushEvents(username: String, token: String?) async -> [PushEventCommit]? {
        guard let url = URL(string: "https://api.github.com/users/\(username)/events?per_page=50") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }

        var results: [PushEventCommit] = []
        for event in json {
            guard (event["type"] as? String) == "PushEvent",
                  let repoDict = event["repo"] as? [String: Any],
                  let fullName = repoDict["name"] as? String,
                  let createdAt = event["created_at"] as? String,
                  let payload = event["payload"] as? [String: Any],
                  let commits = payload["commits"] as? [[String: Any]]
            else { continue }

            let parts = fullName.split(separator: "/")
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repo  = String(parts[1])
            let dateKey = String(createdAt.prefix(10))  // "yyyy-MM-dd"

            for commit in commits {
                guard let sha = commit["sha"] as? String,
                      let message = (commit["message"] as? String) ?? ""
                        as String?
                else { continue }
                results.append(PushEventCommit(
                    owner: owner, repo: repo,
                    sha: sha, message: message, dateKey: dateKey
                ))
            }
        }
        return results
    }

    // MARK: – Private: Commit detail (diff stats)

    private func fetchCommitDetail(owner: String, repo: String, sha: String, token: String?) async -> CommitSummary? {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(sha)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stats = json["stats"] as? [String: Any],
              let files = json["files"] as? [[String: Any]],
              let commitDict = json["commit"] as? [String: Any],
              let message = commitDict["message"] as? String
        else { return nil }

        let additions    = stats["additions"] as? Int ?? 0
        let deletions    = stats["deletions"] as? Int ?? 0
        let filesChanged = files.count
        let repoName     = "\(owner)/\(repo)"

        return CommitSummary(
            repo: repoName, sha: sha, message: message,
            additions: additions, deletions: deletions,
            filesChanged: filesChanged
        )
    }
}
