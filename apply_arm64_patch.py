#!/usr/bin/env python3
from pathlib import Path
import re, shutil, sys

repo = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
pbx = repo/"ChatGPT.xcodeproj/project.pbxproj"
comm = repo/"ChatGPT/Classes/API/CGAPICommunicator.m"
plist = repo/"ChatGPT/SupportingFiles/ChatGPT-Info.plist"
here = Path(__file__).resolve().parent

for p in (pbx, comm, plist):
    if not p.exists():
        raise SystemExit(f"Missing expected file: {p}")

shutil.copy2(pbx, str(pbx)+".bak")
shutil.copy2(comm, str(comm)+".bak")
shutil.copy2(plist, str(plist)+".bak")

shutil.copy2(here/"replacement/CGAPICommunicator.m", comm)
shutil.copy2(here/"replacement/ChatGPT-Info.plist", plist)

s = pbx.read_text(errors="replace")

# Remove the legacy curl shim from compilation.
s = re.sub(r'^.*NSURLConnection\+FoundationCompletions\.m in Sources.*\n', '', s, flags=re.M)

# Remove bundled static SSL/curl/z libraries from project/link phases/file refs/groups.
for lib in ("libcrypto.a", "libcurl.a", "libssl.a", "libz.a"):
    s = re.sub(r'^.*' + re.escape(lib) + r'.*\n', '', s, flags=re.M)

# Modern SDK + arm64 target. VALID_ARCHS is obsolete in modern Xcode, so delete it.
s = re.sub(r'^\s*VALID_ARCHS\s*=\s*[^;]+;\s*\n', '', s, flags=re.M)
s = re.sub(r'^\s*SDKROOT\s*=\s*iphoneos7\.1;\s*$', '\t\t\t\tSDKROOT = iphoneos;', s, flags=re.M)
s = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*5\.0;', 'IPHONEOS_DEPLOYMENT_TARGET = 12.0;', s)
s = re.sub(r'^\s*/Users/virtuellady/Downloads/WOW,\s*\n', '', s, flags=re.M)
s = re.sub(r'^\s*"\$\(PROJECT_DIR\)/ChatGPT/Libraries/SSL",\s*\n', '', s, flags=re.M)

# Explicitly request arm64 for the application target configurations.
needle = 'TARGETED_DEVICE_FAMILY = 1;'
s = s.replace(needle, 'ARCHS = arm64;\n\t\t\t\t' + needle)

# Modern compiler compatibility conveniences.
s = s.replace('CLANG_ENABLE_OBJC_ARC = YES;', 'CLANG_ENABLE_OBJC_ARC = YES;\n\t\t\t\tENABLE_BITCODE = NO;')

pbx.write_text(s)
print("Patched:", repo)
print("Backups: project.pbxproj.bak, CGAPICommunicator.m.bak, ChatGPT-Info.plist.bak")
print("Next: open ChatGPT.xcodeproj in modern Xcode, select your signing team, Build/Archive.")
