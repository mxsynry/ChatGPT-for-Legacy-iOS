# Stage 17 — message branching, Work-style mode & official usage access

Start from Stage 16's independent SwiftUI iOS 16 project. **No bag.xml.**

### Implemented in source

- Branch from a **selected message**, not merely duplicate the entire chat.
- Choose a target **model, mode (Chat/Work-style), temporary storage and reasoning effort** before creating a branch.
- Separate branch provenance and a shortcut back to its original chat.
- Work-style instructions and reasoning effort passed to Responses API; server validates support.
- ChatGPT account usage opens the genuine ChatGPT Usage webpage in an in-app Safari browser.
- Optional API request/token rate-window bars derived **only from real HTTP response headers**.
- Strict billing-mode routing avoids silent OAuth → API-key billing fallback.
- Old local conversations decode with defaults for new branch metadata.

### What remains explicitly unsupported

- This does **not** reproduce official ChatGPT Work's cloud computer, agent mode, plugins, or first-party user quota RPCs.
- No proof of complete official 2026 UI parity, authenticated cloud conversation history, or successful Google/passkey login on iOS 16.
- **Not Xcode compiled or installed on iPhone yet.** The 120 portable regression checks + Swift parser pass are source-level only.

For direct official binary evidence and tests, see `Docs/STAGE17-2026-BRANCH-USAGE-COMPARISON.md` and `Forensics/STAGE17-OFFICIAL-BINARY-EVIDENCE.json`.

Run `bash Scripts/preflight.sh`; on macOS, use the included GitHub Actions build or `xcodegen generate` followed by `xcodebuild`.
