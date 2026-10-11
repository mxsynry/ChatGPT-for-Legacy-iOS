# OpenChat16 reconstruction — Stage 16

Updated from Stage 15; **no bag.xml app source**. This is a separate native SwiftUI iOS 16 source reconstruction based on metadata, architecture hints and documented public interfaces, not an extracted official ChatGPT source tree.

## Stage 16 highlights
- **Always-visible model chooser** that doesn't compete with the compact navigation-bar title.
- Choice retained per chat; no silent model reset when refreshing an account catalog.
- Advanced toggle to display all returned model entries, and a manual model ID override.
- Model selection remains usable in every local chat mode; server compatibility errors are shown rather than hiding client-side options.
- **Separate usage indicator**, showing only actual server-reported request token totals; links to official account usage controls.
- Better structured backend error reporting and contextual plan-limit action.
- Full-message search and branch-this-chat action, useful for comparing models.
- Preserves Stage 15 features, including OAuth experiment, attachment inputs, web citations, streaming and app lock.

## What Stage 16 does NOT do
- It does not bypass server model permissions, paid-plan quotas, unsupported model/tool combinations, account eligibility or safety checks.
- No guarantee of Google/passkey login, subscription plan inference, or native iOS 16 installation until tested.
- No official ChatGPT cloud-history sync; local import only.

## Build and preflight

On Linux/macOS with Swift: `bash Scripts/preflight.sh` (portable tests + Swift parser). On macOS, GitHub Actions generates the Xcode project with XcodeGen, compiles for iOS 16, and packages an unsigned test IPA. No Xcode compilation/device test occurred in this workspace.

See `Docs/STAGE16-MODEL-UX-AND-BACKEND.md` and `Forensics/STAGE16-MODEL-UX-DIRECT-SCAN.json` for exact implementation notes/evidence.
