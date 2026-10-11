#!/usr/bin/env python3
"""Source-level wiring checks, not a substitute for an Xcode or device build."""
from pathlib import Path
root = Path(__file__).resolve().parents[1] / 'App'
files = {p.name: p.read_text() for p in root.glob('*.swift')}
required = {
    'MessageRowView.swift': ['onBranch: () -> Void', 'Branch from this message'],
    'RootView.swift': ['onBranch: { openBranchFromHere(messageID: message.id) }',
                       'BranchCreateSheet(context:', 'branchMode: chat.branchMode',
                       'reasoningEffort: chat.reasoningEffort', 'onRateLimits: { snapshot in'],
    'BranchCreateSheet.swift': ['Which mode?', 'Which model?', 'Create branch from here',
                                'Work-style is a structured chat prompt'],
    'ConversationStore.swift': ['BranchPlanning.prefixCount(', 'BranchProvenance(',
                                'lastRateLimits', 'reasoningEffort'],
    'OpenAIClient.swift': ['private func selectedCredential()', 'switch AuthBillingChoice.route',
                           'RateLimitHeaders.parse(', 'await onRateLimits(snapshot)'],
    'ModelAndUsageBar.swift': ['OfficialUsageBrowser', 'https://chatgpt.com/settings/usage',
                                'API HTTP rate limits (not plan balance)'],
    'ResponsesPayload.swift': ['let instructions: String?', 'let reasoning: Reasoning?',
                                'self.instructions = branchMode.instructions']
}
for file, needles in required.items():
    for needle in needles:
        assert needle in files[file], f'MISSING: {file}: {needle}'
assert 'ChatGPTCredentialProvider.shared.token() ?? CredentialVault.readAPIKey()' not in files['OpenAIClient.swift'], 'Unsafe silent billing fallback'
assert 'account/rateLimits/read' not in files['OpenAIClient.swift'], 'Private first-party usage request in third-party app'
rootView = files['RootView.swift']
assert 'Button("Use ChatGPT plan")' in rootView, 'Missing route back to connected ChatGPT plan'
assert 'chatGPTSignIn.signOut()\n                                        AuthBillingChoice.select(.apiKey)' not in rootView, 'API billing switch must not sign out ChatGPT'
assert 'discardEmptyActivePlaceholder()' in rootView, 'Stop should remove empty assistant placeholders'
print('PASS: Stage 19 UI/backend wiring checks (including account-route preservation)')
