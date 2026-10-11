#!/usr/bin/env python3
"""Reproducible literal evidence from user-provided official ChatGPT IPAs.
No private request is made; scans compiled Mach-O byte strings only.
Usage: python3 stage17_scan_binary.py /path/2024.ipa /path/2026.ipa
"""
import json
import sys
import zipfile
from pathlib import Path

NEEDLES = [
    'DefaultConversationBranchingService',
    'ConversationBranchingService',
    'branchConversation(conversationID:messageID:isContextTruncationContinuation:)',
    'Branch into Work',
    'MessageRowBranchContextLabel',
    'ConversationMode',
    'ConversationModelSelectionStore',
    'SendLongPressModelSelector',
    'UsageLimitsOverviewViewModel',
    'UsageLimitsDashboardViewModel',
    'UsageLimitsDashboardProgressBar',
    'GetAccountRateLimitsParams',
    'ClientRequestAccountRateLimitsReadRequest',
    'account/rateLimits/read',
    'Usage remaining. Five-hour limit:',
    'Usage remaining. Weekly limit:',
    'chatgpt-credits-usage-limits-remaining-percentage',
]

def scan(filename):
    with zipfile.ZipFile(filename) as z:
        raw = z.read('Payload/ChatGPT.app/Frameworks/ChatGPT.framework/ChatGPT')
    return {
        'ipa': Path(filename).name,
        'framework_macho_bytes': len(raw),
        'literal_identifiers_present': {needle: needle.encode('utf8') in raw for needle in NEEDLES}
    }

if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    print(json.dumps({'2024': scan(sys.argv[1]), '2026': scan(sys.argv[2])}, indent=2))
