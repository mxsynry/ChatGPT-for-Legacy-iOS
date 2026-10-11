#!/usr/bin/env python3
"""Source-level guards for the recovery/motion patch; native build still required."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
src = {p.name: p.read_text() for p in (r / 'App').glob('*.swift')}
checks = {
    'RootView.swift': ['pendingStreamRetry', 'StreamRetryBanner(', 'retryInterruptedResponse()',
                       'store.markInterrupted(messageID, in: conversationID)', 'historyOverride: history',
                       'case .interrupted(let detail)', 'diagnostic.retryAfter'],
    'OpenAIClient.swift': ['case .interrupted(let event)', 'case .incomplete(let reason)',
                           'cause: .connectionClosed', 'cause: .connectionError',
                           'if completed { break }', 'headers: headers'],
    'ConversationStore.swift': ['var isInterrupted: Bool = false', 'func markInterrupted(',
                                'isInterrupted = try c.decodeIfPresent(Bool.self'],
    'ResponsesPayload.swift': ['messages.filter { $0.role != "assistant" || !$0.isInterrupted }'],
    'MessageRowView.swift': ['Label("Interrupted response"'],
    'BackportMotion.swift': ['accessibilityReduceMotion', 'BackportActivityDots', 'StreamRetryBanner'],
    'ResponseRetryContext.swift': ['inputForManualRetry', 'return Array(messages.prefix(userIndex + 1))'],
}
for filename, tokens in checks.items():
    for token in tokens:
        assert token in src[filename], f'{filename} missing {token}'
assert 'api.openai.com/v1/responses' in src['OpenAIClient.swift']
assert 'store = false' in src['ResponsesPayload.swift']
assert not list((r / 'App').rglob('*.lottie')), 'Closed-source official Lottie assets unexpectedly committed to app'
print('PASS: manual retry and independent native motion wiring checks')
