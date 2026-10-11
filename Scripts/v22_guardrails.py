#!/usr/bin/env python3
"""Fail fast on a small set of regressions that Swift -frontend -parse misses.

This is a source audit, NOT a substitute for an iOS SDK typecheck/build.
"""
from pathlib import Path
from collections import defaultdict
import re

root = Path(__file__).resolve().parent.parent
app = root / 'App'
source = {p.name: p.read_text(encoding='utf8') for p in app.glob('*.swift')}
assert len(source) >= 30, f'Unexpected loss of app source files: {len(source)}'
assert 'ConversationFileRecovery.swift' in source

# Detect accidental repeated top-level type definitions across modules.
types = defaultdict(list)
type_pattern = re.compile(r'^(?:(?:private|fileprivate|public|internal|open|final|indirect)\s+|@MainActor\s+)*(?:struct|enum|class|actor|protocol)\s+([A-Za-z_]\w*)', re.M)
for name, content in source.items():
    for match in type_pattern.finditer(content):
        types[match.group(1)].append(name)
duplicates = {name: files for name, files in types.items() if len(files) > 1}
assert not duplicates, f'Duplicate top-level Swift types: {duplicates}'

store = source['ConversationStore.swift']
assert 'ConversationFileRecovery.load' in store
assert 'guard diskWritesEnabled else { return }' in store
assert 'filter { !$0.isTemporary }' in store
assert 'startupRecoveryNotice' in store
view = source['RootView.swift']
assert 'Saved-history recovery' in view
assert 'authorizeSensitiveExport()' in view
assert 'if let url = exportURL, url != store.recoveryFileURL' in view
assert 'showSettings' in view
# Presentation scope must remain inside Settings, but moving views into
# computed properties changes their lexical order within RootView.swift.
# Checking mere string position incorrectly rejects that valid refactor.
assert '.sheet(isPresented: $showSettings)' in view
assert 'private var settingsSheetContent: some View' in view
settings_scope = view.split('private var settingsSheetContent: some View {', 1)[1].split('private var modelPickerContent: some View {', 1)[0]
assert '.fileImporter(isPresented: $showHistoryImporter' in settings_scope
assert '.sheet(isPresented: $showExport' in settings_scope
# Guard against one huge SwiftUI body forcing Apple's constraint solver to time out.
root_body = view.split('var body: some View {', 1)[1].split('private var settingsAccountSection: some View', 1)[0]
assert root_body.count('\n') < 110, 'RootView.body grew into a monolithic expression again'
for part in ('navigationContent', 'mainChatWithHandlers', 'transcriptScrollView',
             'chatComposer', 'settingsSheetContent', 'sidebarSheetContent',
             'modelPickerContent', 'mainChatColumn'):
    assert 'private var ' + part + ': some View' in view, 'Missing isolated UI component: ' + part

project = (root / 'project.yml').read_text()
assert "IPHONEOS_DEPLOYMENT_TARGET: '16.0'" in project
assert 'sources: [App]' in project
assert not any(p.suffix.lower() in {'.ipa', '.dylib', '.a'} for p in app.rglob('*') if p.is_file())
assert not any('.framework' in p.parts for p in app.rglob('*') if p.is_file())
print(f'PASS: V22 guardrails, {len(source)} Swift files, {len(types)} top-level types')
