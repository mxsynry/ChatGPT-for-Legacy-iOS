# Stage 17 — Message-aware branches, mode choice, and legitimate usage reporting

## 1. Evidence directly from the user-supplied decrypted IPAs

The accompanying `Forensics/STAGE17-OFFICIAL-BINARY-EVIDENCE.json` is the output of a **direct literal byte-string scan** of `ChatGPT.framework/ChatGPT` in the user's 2024 and 2026 IPAs. Re-run it with the bundled `Forensics/stage17_scan_binary.py` and the two IPA paths; no official framework binaries are redistributed here.

Confirmed present in the **2026** framework and absent as literal strings in the **2024** framework:

- `branchConversation(conversationID:messageID:isContextTruncationContinuation:)`
- `Branch into Work`
- `DefaultConversationBranchingService`
- `MessageRowBranchContextLabel`
- `UsageLimitsOverviewViewModel`
- `UsageLimitsDashboardViewModel`
- `UsageLimitsDashboardProgressBar`
- `ClientRequestAccountRateLimitsReadRequest`
- `account/rateLimits/read`
- `Usage remaining. Five-hour limit:`
- `Usage remaining. Weekly limit:`
- `chatgpt-credits-usage-limits-remaining-percentage`

This establishes component/feature **existence**, not executable source recovery. The official first-party framework does have message-anchored branching and more sophisticated usage tracking than our previous clone. The private RPC identifiers do not establish a supported third-party OAuth scope to use them.

## 2. What was actually broken in Stage 16

- `ConversationStore.branch(from:)` copied **every** message and gave no selected-message anchor or mode choice. It was duplication, not message branching.
- Branches carried no ancestry marker, nor route/mode/effort choice.
- Usage sheet displayed per-request token counts, without a way to show real plan usage in the client.
- `OpenAIClient` still had an expression combining `ChatGPTCredentialProvider.shared.token()` and `CredentialVault.readAPIKey()` with `??` even when ChatGPT plan billing was selected. That created a silent API-key billing fallback risk if the provider ever returned nil.

## 3. Stage 17 implementation

- Long-press **any user/assistant message** → `Branch from this message…`. The new branch retains messages *through the selected item*; later turns exist only in the parent.
- A visible branch button in the model bar and toolbar opens `Branch into…` with model, Chat/Work-style mode, temporary storage, and reasoning effort choices.
- Branch metadata stores parent conversation ID, selected source message ID, and creation time. Old JSON conversations still decode with new fields defaulted.
- Branches have independent model preference; selecting a model does not mutate the parent. Original chat remains accessible from a branch's small context header.
- Work-style mode adds an explicit structured-task `instructions` field to the **public Responses API** request. **It does not provide the official ChatGPT Work runtime, cloud browser, apps/connectors, or agent execution.** Work-style was chosen as a truthful label instead of pretending that private Work endpoints are available.
- Reasoning effort choices are `model default`, `low`, `medium`, `high`, `xhigh`. The chosen value goes in `reasoning.effort` on Responses requests if non-default. Models vary in supported values; unsupported values return genuine service errors.
- The usage sheet's **View ChatGPT usage in app** opens the genuine ChatGPT Settings → Usage webpage via `SFSafariViewController`. This displays genuine account/app limits after browser sign-in, when available. The native OAuth session is **not** silently injected into the browser. If the route changes, navigate to Settings → Usage from the ChatGPT website.
- Rate-limit request/token windows are decoded from actual `x-ratelimit-*` HTTP response headers, where provided. The app never presents these as the ChatGPT plan's shared five-hour or weekly allowance. Request token totals remain labeled as *last response*, not remaining capacity.
- Billing route resolution now explicitly switches on `AuthBillingChoice.route` for both inference and model discovery. It will not charge an API key on an OAuth failure unless the user explicitly selected API-key mode.

## 4. What we cannot claim

- The 2026 binary's private first-party `account/rateLimits/read` RPC cannot be assumed callable with a third-party Sign in with ChatGPT OAuth token. The public flow grants plan inference on supported endpoints, not an arbitrary permission to read first-party account internals.
- The actual *Work mode* backend is not reproduced by a prompt. Our local `Work-style` branch is a productivity-oriented response preset with manual interaction; it cannot operate the cloud browser or act as the official agent.
- The official 2026 Swift source itself has **not** been reconstructed. The evidence is compiled identifiers and product-level behavior.
- No successful Xcode build, device install, Google sign-in or passkey login has been established by the automated checks.

## 5. Device test checklist

1. Install unsigned IPA built from this source on iPhone 8 Plus / iOS 16.7.16 (TrollStore). Verify launch first.
2. On an existing long chat, long-press an early **assistant** reply → Branch from this message → select another model, choose `High` effort → Create. Verify only messages up to that answer are copied and parent is untouched.
3. From a **user** message, branch into `Work-style`; verify title, source link, model selection and response instruction routing.
4. Switch branch/original repeatedly; verify unsent draft restoration and no messages written to the wrong conversation.
5. Enter ChatGPT-plan mode and deliberately cause OAuth expiration; ensure no API-key usage without explicit selection.
6. Usage button in ChatGPT-plan mode → open ChatGPT Settings → Usage in browser; authenticate if required and view actual app/plan limits.
7. API-key mode → check `x-ratelimit-*` headers in a response if provided; only then should a native request-rate gauge appear.
8. Try a model that does not support `xhigh`. The server's error should be surfaced without silently downgrading the requested effort.

## Official public references

- https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
- https://developers.openai.com/siwc/ui-ux-guidelines
- https://developers.openai.com/api/docs/guides/rate-limits
- https://developers.openai.com/api/docs/guides/reasoning
