#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
BIN="$(mktemp "${TMPDIR:-/tmp}/openchat16-regression.XXXXXX")"
trap 'rm -f "$BIN"' EXIT
swiftc -O App/OAuthCallbackSafety.swift App/OAuthAuthorizationBuilder.swift \
  App/OAuthSessionSafety.swift App/ChatGPTHistoryImporter.swift \
  App/ResponsesPayload.swift App/ResponseStreamEvents.swift App/ModelCatalog.swift App/BackendDiagnostics.swift App/StreamRecovery.swift App/BranchPlanning.swift App/RateLimitHeaders.swift \
  App/BranchNavigation.swift App/SSEFrameCollector.swift \
  App/StreamingTextBatcher.swift App/ConversationListPolicy.swift \
  App/OAuthLoopbackHTTP.swift App/MarkdownSegments.swift App/CitationURLPolicy.swift \
  Tests/RegressionMain.swift -o "$BIN"
"$BIN"
swiftc -frontend -parse App/*.swift
python3 Scripts/stage17_wiring_check.py
python3 Scripts/stage20_wiring_check.py
python3 Scripts/stage21_review.py
python3 Scripts/v22_guardrails.py
python3 Scripts/stream_motion_wiring_check.py
# Unlike -frontend -parse, this actually type-checks the real ConversationStore
# source and catches duplicate properties/methods that slipped into Stage 20.
swiftc -typecheck App/ConversationFileRecovery.swift App/ConversationStore.swift App/ResponseStreamEvents.swift App/StreamRecovery.swift App/ResponseRetryContext.swift App/BackendDiagnostics.swift \
  App/CitationURLPolicy.swift App/RateLimitHeaders.swift App/BranchPlanning.swift \
  App/ChatGPTHistoryImporter.swift
STORE_TEST="$(mktemp "${TMPDIR:-/tmp}/openchat16-storetest.XXXXXX")"
trap 'rm -f "$BIN" "$STORE_TEST"' EXIT
swiftc -O App/ConversationFileRecovery.swift App/ConversationStore.swift App/ResponseStreamEvents.swift App/StreamRecovery.swift App/ResponseRetryContext.swift App/BackendDiagnostics.swift \
  App/CitationURLPolicy.swift App/RateLimitHeaders.swift App/BranchPlanning.swift \
  App/ChatGPTHistoryImporter.swift \
  Tests/StoreBehaviorMain.swift -o "$STORE_TEST"
"$STORE_TEST"
RECOVERY_TEST="$(mktemp "${TMPDIR:-/tmp}/openchat16-retrytest.XXXXXX")"
trap 'rm -f "$BIN" "$STORE_TEST" "$RECOVERY_TEST"' EXIT
swiftc -Onone App/ConversationFileRecovery.swift App/ConversationStore.swift App/ResponseStreamEvents.swift \
  App/StreamRecovery.swift App/ResponseRetryContext.swift App/BackendDiagnostics.swift \
  App/CitationURLPolicy.swift App/RateLimitHeaders.swift App/BranchPlanning.swift \
  App/ChatGPTHistoryImporter.swift Tests/StreamRecoveryMain.swift -o "$RECOVERY_TEST"
"$RECOVERY_TEST"
if grep -R -n -E '(https://chatgpt\.com/backend-api|https://chat\.openai\.com/backend-api|/backend-api/)' App; then
  echo "ERROR: private ChatGPT backend path found in app source" >&2
  exit 1
fi
printf '%s\n' 'PASS: Stage 22 source parse + store typecheck + regression checks + no private backend usage'
