"""Static packaging checks, not a macOS/hardware compatibility test."""
from pathlib import Path
import plistlib
import re
import subprocess

root = Path(__file__).resolve().parents[1]
source = {p.name: p.read_text() for p in (root / 'Sources').glob('*.swift')}
all_source = '\n'.join(source.values())
assert all_source.count('setEnabled(false,') == 1, 'There must be one guarded disable call'
assert 'setEnabled(false,' in source['Guardian.swift']
assert 'CGCompleteDisplayConfiguration(config, .forSession)' in source['DisplayBridge.swift']
assert 'CGCompleteDisplayConfiguration(config, .permanently)' not in all_source
assert 'CGDisplayIsBuiltin(id) == 1' in all_source
assert 'CGDisplayIsActive(id) == 1' in all_source
assert 'policy.shuttingDown' in source['Guardian.swift']
assert 'bridge.saveRecovery(panel)' in source['Guardian.swift']
assert source['Guardian.swift'].index('bridge.saveRecovery(panel)') < source['Guardian.swift'].index('setEnabled(false,')
for token in ['URLSession', 'CGDisplaySetDisplayMode', 'CGSetDisplayTransfer', 'CGDisplayCapture', 'CGVirtualDisplay', 'IOServiceOpen']:
    assert token not in all_source, token
for script in root.glob('*.command'):
    subprocess.run(['bash', '-n', str(script)], check=True)
    # Ignore comments and human-facing echo/printf strings; look for command invocations.
    assert not re.search(r'^\s*(sudo|curl|wget|spctl|csrutil|xattr)\b', script.read_text(), re.M), script
    assert script.stat().st_mode & 0o111, script
info = plistlib.loads((root / 'Info.plist').read_bytes())
assert info['LSUIElement'] is True
assert info['CFBundleExecutable'] == 'iMacSolo'
assert info['CFBundleIdentifier'] == 'local.imacsolo.app'
assert 'MACOS SDK' not in all_source  # no embedded fake SDK or placeholder SDK paths
print('PASS: static guard-path, session-only, script syntax, permission and bundle-metadata checks.')
