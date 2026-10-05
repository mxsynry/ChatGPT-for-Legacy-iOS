# ARM64 / iOS 16 build notes

This tree has been normalized for a modern Xcode unsigned device build while preserving the legacy UI and application behavior.

Changes applied:
- ARM64-only application build; iOS 16 deployment target.
- Removed obsolete `VALID_ARCHS`, Xcode 5 `iphoneos7.1`, and machine-specific library paths.
- Removed bundled legacy OpenSSL/curl/z static archives and the curl-backed `NSURLConnection` implementation from the target.
- Replaced the API communicator with the repository's NSURLSession implementation.
- Updated the application Info.plist to require arm64 and use valid modern bundle version values.
- Removed Info.plist from Copy Bundle Resources.
- Removed obsolete Interface Builder deployment encodings from all XIB/storyboard files so current `ibtool` uses the target deployment setting.
- Made `apply_arm64_patch.py` idempotent so GitHub Actions can safely run it on an already-modernized checkout.

The project intentionally retains older UIKit APIs such as UIAlertView/UIActionSheet for now because they remain compile-compatible and changing them before a successful baseline build risks UI regressions.
