#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
BIN="$(mktemp "${TMPDIR:-/tmp}/openchat16-regression.XXXXXX")"
trap 'rm -f "$BIN"' EXIT
swiftc -O App/OAuthCallbackSafety.swift App/OAuthAuthorizationBuilder.swift \
  App/OAuthSessionSafety.swift App/ChatGPTHistoryImporter.swift \
  App/ResponsesPayload.swift App/ResponseStreamEvents.swift App/ModelCatalog.swift App/BackendDiagnostics.swift App/BranchPlanning.swift App/RateLimitHeaders.swift \
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
# Unlike -frontend -parse, this actually type-checks the real ConversationStore
# source and catches duplicate properties/methods that slipped into Stage 20.
swiftc -typecheck App/ConversationFileRecovery.swift App/ConversationStore.swift App/ResponseStreamEvents.swift \
  App/CitationURLPolicy.swift App/RateLimitHeaders.swift App/BranchPlanning.swift \
  App/ChatGPTHistoryImporter.swift
STORE_TEST="$(mktemp "${TMPDIR:-/tmp}/openchat16-storetest.XXXXXX")"
trap 'rm -f "$BIN" "$STORE_TEST"' EXIT
swiftc -O App/ConversationFileRecovery.swift App/ConversationStore.swift App/ResponseStreamEvents.swift \
  App/CitationURLPolicy.swift App/RateLimitHeaders.swift App/BranchPlanning.swift \
  App/ChatGPTHistoryImporter.swift \
  Tests/StoreBehaviorMain.swift -o "$STORE_TEST"
"$STORE_TEST"
if grep -R -n -E '(https://chatgpt\.com/backend-api|https://chat\.openai\.com/backend-api|/backend-api/)' App; then
  echo "ERROR: private ChatGPT backend path found in app source" >&2
  exit 1
fi
printf '%s\n' 'PASS: Stage 22 source parse + store typecheck + regression checks + no private backend usage'
