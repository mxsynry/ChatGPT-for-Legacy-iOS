#!/usr/bin/env python3
"""Inventory user-supplied decrypted official client IPAs without executing binaries.

Usage: python3 Scripts/inventory_decrypted_ipas.py --older /path/2024.ipa --newer /path/2026.ipa --output Docs/OfficialClient
Never commits original proprietary assets; optional --private-assets destination
extracts them outside the app tree as personal research references only.
"""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import plistlib
from pathlib import Path
from collections import Counter
from zipfile import ZipFile

ASSET_SUFFIXES = {'.lottie', '.ahap'}

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()

def ipascan(path: Path, private_assets: Path | None = None) -> dict:
    result = {'filename': path.name, 'bytes': path.stat().st_size, 'sha256': sha256(path)}
    with ZipFile(path) as z:
        names = [item.filename for item in z.infolist() if not item.is_dir()]
        result['fileCount'] = len(names)
        result['fileTypes'] = dict(Counter(Path(n).suffix.lower() for n in names).most_common())
        result['extensions'] = sorted(Path(n).parent.name for n in names if n.endswith('.appex/Info.plist'))
        result['featureBundles'] = sorted(set(Path(n).parent.name for n in names if n.endswith('.bundle/Info.plist')))
        info_paths = ['Payload/ChatGPT.app/Info.plist',
                      'Payload/ChatGPT.app/Frameworks/ChatGPT.framework/Info.plist']
        result['version'] = {}
        for info_path in info_paths:
            if info_path in names:
                meta = plistlib.loads(z.read(info_path))
                result['version']['app' if '/Frameworks/' not in info_path else 'framework'] = {
                    key: meta.get(key) for key in ['CFBundleShortVersionString',
                                                  'MinimumOSVersion', 'CFBundleIdentifier']
                }
        result['proprietary3DAssetCount'] = sum(1 for n in names if n.endswith(('.orbitmesh', '.orbitfaces')))
        result['animations'] = []
        for n in names:
            ext = Path(n).suffix.lower()
            if ext not in ASSET_SUFFIXES and not n.endswith('orbit-creation-motion.json'):
                continue
            data = z.read(n)
            asset = {'path': n, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                     'kind': ext or 'motion-json'}
            if ext == '.lottie':
                try:
                    with ZipFile(io.BytesIO(data)) as lottie:
                        animation = json.loads(lottie.read('animations/animation.json'))
                        frame_rate = float(animation.get('fr', 0))
                        start, end = animation.get('ip'), animation.get('op')
                        asset['animation'] = {
                            'name': animation.get('nm'), 'fps': frame_rate,
                            'startFrame': start, 'endFrame': end,
                            'durationSeconds': round((end - start) / frame_rate, 3)
                                if isinstance(start, (float, int)) and isinstance(end, (float, int))
                                and frame_rate else None,
                            'size': [animation.get('w'), animation.get('h')],
                            'layers': len(animation.get('layers', [])),
                        }
                except Exception as exc:
                    asset['parseError'] = type(exc).__name__
            if n.endswith('orbit-creation-motion.json'):
                try:
                    motion = json.loads(data)
                    fps = motion.get('framesPerSecond')
                    frames = motion.get('frames', [])
                    asset['animation'] = {
                        'fps': fps, 'frames': len(frames), 'loopStart': motion.get('loopStart'),
                        'durationSeconds': round(len(frames) / fps, 3) if fps else None,
                        'channelsPerFrame': len(frames[0]) if frames else 0,
                    }
                except Exception as exc:
                    asset['parseError'] = type(exc).__name__
            if ext == '.ahap':
                try:
                    haptic = json.loads(data)
                    pattern = haptic.get('Pattern', [])
                    asset['haptic'] = {'events': len([e for e in pattern if 'Event' in e]),
                                       'parameterCurves': len([e for e in pattern if 'ParameterCurve' in e])}
                except Exception as exc:
                    asset['parseError'] = type(exc).__name__
            if private_assets is not None:
                # Avoid spreading any official-IPA asset into the public repo.
                folder = private_assets / ('2024' if '2024' in path.name else '2026')
                folder.mkdir(parents=True, exist_ok=True)
                # The names are distinct in the inspected IPAs.
                (folder / Path(n).name).write_bytes(data)
            result['animations'].append(asset)
    return result

def markdown(rows: list[dict]) -> str:
    text = ['# Official IPA asset and motion audit', '',
            'Evidence from user-provided decrypted IPAs. This is static resource inspection,',
            '**not a claim that every packaged module is functional, that animation curves',
            'were recovered from compiled code, or that server-dependent features can be ported.**', '']
    for row in rows:
        app = row['version'].get('app', {})
        fw = row['version'].get('framework', {})
        text.extend([
            '## ' + row['filename'], '',
            '- App version: `' + str(app.get('CFBundleShortVersionString')) + '`',
            '- App minimum iOS (metadata): `' + str(app.get('MinimumOSVersion')) + '`',
            '- Framework minimum iOS: `' + str(fw.get('MinimumOSVersion')) + '`',
            '- Inventory: ' + str(row['fileCount']) + ' files, ' + str(len(row['featureBundles'])) + ' feature bundles, '
              + str(len(row['extensions'])) + ' extensions, ' + str(row['proprietary3DAssetCount']) + ' proprietary 3D assets',
            '- SHA-256: `' + row['sha256'] + '`', '',
            '### Motion resources', '',
            '| Resource | Type | Timing / structure |', '|---|---|---|'])
        for a in row['animations']:
            specs = a.get('animation', {})
            desc = (f"{specs.get('fps')} fps; {specs.get('durationSeconds')} s" if specs else '')
            if 'haptic' in a: desc = f"{a['haptic']['events']} haptic events, {a['haptic']['parameterCurves']} parameter curves"
            text.append(f"| `{Path(a['path']).name}` | {a['kind']} | {desc} |")
        text.extend(['', '### Feature bundles / extensions', '',
                     'Bundles: ' + ', '.join('`' + x + '`' for x in row['featureBundles']) if row['featureBundles'] else 'No individual feature bundles found.',
                     '', 'Extensions: ' + ', '.join('`' + x + '`' for x in row['extensions']) if row['extensions'] else 'No extensions found.', ''])
    text.extend(['## Porting decisions', '',
                 '- Actual `.lottie` packages were found only in 2026, associated with birthday UI; they are **not** the general navigation animation system.',
                 '- `orbit-creation-motion.json`, `.orbitmesh` and `.orbitfaces` describe a proprietary visual pipeline; data files alone are not a working iOS 16 animation engine.',
                 '- 2024 and 2026 AHAP haptics can be mapped to system haptic feedback, but require on-device hardware checks.',
                 '- Built-in SwiftUI sheets, view transitions, and app state changes are compiled code, not extractable keyframe assets. Our `BackportMotion.swift` is an **independent iOS 16 approximation**.',
                 '- Official animation files stay as optional private research references. They are not automatically added to a public repository or bundled as if supported.', ''])
    return '\n'.join(text)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--older', type=Path, required=True)
    parser.add_argument('--newer', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('Docs/OfficialClient'))
    parser.add_argument('--private-assets', type=Path, default=None)
    args = parser.parse_args()
    scanned = [ipascan(args.older, args.private_assets), ipascan(args.newer, args.private_assets)]
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'animation-inventory.json').write_text(json.dumps(scanned, indent=2, ensure_ascii=False) + '\n')
    (args.output / 'ANIMATION-AND-FEATURE-AUDIT.md').write_text(markdown(scanned))
    print('PASS: inspected', ', '.join(f"{x['version']['app']['CFBundleShortVersionString']} ({len(x['animations'])} motion resources)" for x in scanned))
