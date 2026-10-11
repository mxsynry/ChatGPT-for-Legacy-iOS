#!/usr/bin/env python3
"""Static wiring smoke checks; NOT a native iOS typecheck or device test."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
files={p.name:p.read_text() for p in (r/'App').glob('*.swift')}
requirements={
 'RootView.swift': ['PrivateChatAccess()', 'ConversationListPolicy.visible(',
                    'onProgress: { text in', 'chatGPTSignIn.testLoopback()',
                    'authorizeSensitiveExport()', 'MessageRowView(',
                    'ChatComposerView(', 'privateChatAccess.revokeAll()',
                    'showModelPicker = true', 'privacyShieldActive = true'],
 'ConversationStore.swift': ['isPinned: Bool', 'isArchived: Bool', 'isLocked: Bool',
                             'webSearchEnabled: Bool', 'setPinned(', 'setArchived(',
                             'setLocked(', 'setWebSearch(', 'decodeIfPresent(Bool.self, forKey: .isLocked)'],
 'PrivateChatAccess.swift': ['deviceOwnerAuthentication', 'revokeAll()', 'authorizeSensitiveExport()'],
 'OAuthLoopbackHTTP.swift': ['hostHeaders.count == 1', 'hostHeaders[0]', 'requestTarget.hasPrefix'],
 'ChatGPTSignIn.swift': ['OAuthLoopbackHTTP.callbackURL(', 'func testLoopback() async',
                        'ChatGPTSessionVault.save(newSession)'],
 'MessageRowView.swift': ['MessageContentView(text:', '.contextMenu {'],
 'MessageContentView.swift': ['MarkdownRenderCache.split(text)', 'UIPasteboard.general.string = code'],
 'ResponseStreamEvents.swift': ['CitationURLPolicy.allow(link)', 'case progress(String)',
                               'case "response.web_search_call.in_progress"'],
 'OpenAIClient.swift': ['onProgress:', 'await onProgress(status)', 'ChatGPTCredentialProvider.shared.token()',
                       'request.setValue("no-store", forHTTPHeaderField: "Cache-Control")'],
}
count=0
for name,needles in requirements.items():
 for token in needles:
  assert token in files[name],f'{name} missing {token}'
  count+=1
assert not any('https://chatgpt.com/backend-api' in content for content in files.values())
assert 'if let chat = selected { store.saveDraft(input, in: chat.id) }' in files['RootView.swift'], 'Inactive phase must preserve draft before wiping text'
assert 'case .chatgptPlan:' in files['OpenAIClient.swift'] and 'case .apiKey:' in files['OpenAIClient.swift']
print(f'PASS: {count} Stage 20 source wiring assertions (not Xcode typechecking)')
