#!/usr/bin/env python3
"""Evidence-only scanner: no binary copying, strings dumped, or account data.
Pass official IPA archive paths and receive bounded indicator hit offsets.
A hit is not decompiled source and does not establish runtime behavior.
"""
import argparse, json, pathlib, zipfile

IDENTIFIERS = [
    'CalpicoMessageActionsSheet',
    'CalpicoMessageContextMenuInteraction',
    'MessageRowContextMenuPart',
    'SendLongPressModelSelector',
    'ComposerModelPickerUIKitMenuBuilder',
    'ConversationDraftLifecycleTracker',
    'MessageSourcesView',
    'MessageEditingAttachmentRestorer',
    'ConversationBranchingService',
    'ConversationModelSelectionStore',
    'UsageLimitsDashboardViewModel',
    'UsageLimitsDashboardProgressBar',
    'LockedChatsBiometricCredentialStore',
    'NativeAuthPasskeyAuthenticator',
    'NativeAuthUsernamelessPasskeyLoginCoordinator',
    'CalpicoConversationsRepository',
    'FileCalpicoConversationsCache',
    'ChatGPTWritingBlocks',
    'ChatGPTAudioAttachments',
    'ChatGPTConnectors',
    'ChatGPTMemory',
    'ChatGPTVoice',
    'ChatGPTLockedChats',
    'ChatGPTLogin',
]


def scan(path):
    with zipfile.ZipFile(path) as archive:
        binary_name = next(name for name in archive.namelist()
                           if name.endswith('/Frameworks/ChatGPT.framework/ChatGPT'))
        binary = archive.read(binary_name)
        indicators = {}
        for name in IDENTIFIERS:
            raw = name.encode('utf-8')
            cursor = 0
            offsets = []
            while True:
                offset = binary.find(raw, cursor)
                if offset < 0:
                    break
                if len(offsets) < 8:
                    offsets.append(offset)
                cursor = offset + len(raw)
            indicators[name] = {'found': bool(offsets), 'sample_offsets': offsets}
        return {'framework_member': binary_name, 'framework_bytes': len(binary),
                'indicators': indicators}


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument('--ipa-2024', required=True)
    cli.add_argument('--ipa-2026', required=True)
    cli.add_argument('--output', required=True)
    args = cli.parse_args()
    payload = {'scope': 'literal identifier scan of supplied official IPA binaries',
               'warning': 'Literal references are not original source or proof of behavior.',
               '2024': scan(args.ipa_2024), '2026': scan(args.ipa_2026)}
    pathlib.Path(args.output).write_text(json.dumps(payload, ensure_ascii=False, indent=2))
    print(f"Saved evidence for {len(IDENTIFIERS)} identifiers across both IPA frameworks.")


if __name__ == '__main__':
    main()
