#!/usr/bin/env python3
"""V21 source assertions. These check wiring, NOT UIKit/SwiftUI typechecking."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
source={x.name:x.read_text() for x in (r/'App').glob('*.swift')}
store=source['ConversationStore.swift']
for symbol in ['var isPinned:', 'var isArchived:', 'var isLocked:', 'var webSearchEnabled:',
               'func setPinned(', 'func setArchived(', 'func setLocked(', 'func setWebSearch(']:
    assert store.count(symbol)==1,f'Duplicate declaration slipped into V21: {symbol}'
assert 'func appendDelta(' in store and 'streamingTick &+= 1' in store
assert 'lastStreamPersistence) >= 8.0' in store
assert '@Published private(set) var streamingTick' not in store
assert 'MessageRowView(' in source['RootView.swift']
assert 'isStreaming: activeConversation ==' in source['RootView.swift']
assert 'AttachmentThumbnailView(messageID:' in source['MessageRowView.swift']
assert 'Data(base64Encoded:' not in source['MessageRowView.swift']
assert 'Text(message.text.isEmpty ?' in source['MessageRowView.swift']
assert 'Task.detached(priority: .utility)' in source['AttachmentThumbnailView.swift']
assert 'CGImageSourceCreateThumbnailAtIndex' in source['AttachmentThumbnailView.swift']
assert 'CGImageSourceCreateThumbnailAtIndex' in source['ImagePreparation.swift']
assert 'MarkdownRenderCache.split(text)' in source['MessageContentView.swift']
assert 'ThumbnailCache.clear()' in source['RootView.swift']
assert 'MarkdownRenderCache.clear()' in source['RootView.swift']
assert 'Color(.systemBackground)' in source['ChatComposerView.swift']
assert '.onChange(of: store.streamingTick)' in source['RootView.swift']
assert '.onChange(of: selected?.messages.last?.text)' not in source['RootView.swift']
assert 'store.appendDelta(delta, to: messageID, in: conversationID)' in source['RootView.swift']
assert 'Task.detached(priority: .utility)' in source['RootView.swift']
assert 'ImagePreparation.jpeg(fromEncodedImageData: data)' in source['RootView.swift']
assert 'privacyShieldActive = true' in source['RootView.swift']
assert 'privateChatAccess.revokeAll()' in source['RootView.swift']
assert 'AuthBillingChoice.route' in source['OpenAIClient.swift']
print('PASS: 21 Stage 21 rendering/UI and security wiring checks')
