#!/usr/bin/env python3
from pathlib import Path
import re, shutil, sys

repo = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
pbx = repo / "ChatGPT.xcodeproj/project.pbxproj"
comm = repo / "ChatGPT/Classes/API/CGAPICommunicator.m"
plist = repo / "ChatGPT/SupportingFiles/ChatGPT-Info.plist"
here = Path(__file__).resolve().parent

for p in (pbx, comm, plist):
    if not p.exists():
        raise SystemExit(f"Missing expected file: {p}")

if (here / "replacement/CGAPICommunicator.m").exists():
    shutil.copy2(here / "replacement/CGAPICommunicator.m", comm)
if (here / "replacement/ChatGPT-Info.plist").exists():
    shutil.copy2(here / "replacement/ChatGPT-Info.plist", plist)

for ib in list((repo / "ChatGPT").rglob("*.xib")) + list((repo / "ChatGPT").rglob("*.storyboard")):
    text = ib.read_text(errors="replace")
    text = re.sub(r'<deployment\b[^>]*/>', '<deployment identifier="iOS"/>', text)
    ib.write_text(text)

s = pbx.read_text(errors="replace")
for token in ("NSURLConnection+FoundationCompletions.m", "libcrypto.a", "libcurl.a", "libssl.a", "libz.a"):
    s = "\n".join(line for line in s.split("\n") if token not in line)
s = "\n".join(line for line in s.split("\n") if "ChatGPT-Info.plist in Resources" not in line)

# Repair an early patcher's escaped-newline artifact, if present.
s = s.replace(r'ARCHS = arm64;\n\t\t\t\tTARGETED_DEVICE_FAMILY = 1;', 'TARGETED_DEVICE_FAMILY = 1;')
s = re.sub(r'^\s*VALID_ARCHS\s*=\s*[^;]+;\s*\n?', '', s, flags=re.M)
s = re.sub(r'^\s*"?\$\(PROJECT_DIR\)/ChatGPT/Libraries/SSL"?,?\s*\n?', '', s, flags=re.M)
s = re.sub(r'^\s*/Users/virtuellady/Downloads/WOW,?\s*\n?', '', s, flags=re.M)
s = re.sub(r'SDKROOT\s*=\s*iphoneos7\.1;', 'SDKROOT = iphoneos;', s)
s = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*[^;]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 16.0;', s)
s = re.sub(r'^\s*ARCHS\s*=\s*arm64;\s*\n?', '', s, flags=re.M)
s = s.replace('TARGETED_DEVICE_FAMILY = 1;', 'ARCHS = arm64;\n\t\t\t\tTARGETED_DEVICE_FAMILY = 1;')
if 'ENABLE_BITCODE = NO;' not in s:
    s = s.replace('CLANG_ENABLE_OBJC_ARC = YES;', 'CLANG_ENABLE_OBJC_ARC = YES;\n\t\t\t\tENABLE_BITCODE = NO;')

pbx.write_text(s)
print("Modernized project for unsigned arm64 / iOS 16 build:", repo)
