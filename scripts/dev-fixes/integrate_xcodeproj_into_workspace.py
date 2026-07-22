#!/usr/bin/env python3
from pathlib import Path
import xml.etree.ElementTree as ET
import sys

WORKSPACE = Path('/Users/nicreich/AetherAG-mono/Aether.xcworkspace/contents.xcworkspacedata')
PROJECT_REL = 'AetherAGMailClientAppShell/AetherAGMailClientAppShell.xcodeproj'
FILE_REF = f'group:{PROJECT_REL}'

if not WORKSPACE.exists():
    print(f'ERROR: workspace file not found: {WORKSPACE}', file=sys.stderr)
    sys.exit(1)

xml_text = WORKSPACE.read_text()
try:
    root = ET.fromstring(xml_text)
except ET.ParseError as e:
    print(f'ERROR: failed to parse workspace XML: {e}', file=sys.stderr)
    sys.exit(1)

if root.tag != 'Workspace':
    print(f'ERROR: unexpected root tag: {root.tag}', file=sys.stderr)
    sys.exit(1)

existing_refs = root.findall('FileRef')
for ref in existing_refs:
    if ref.attrib.get('location') == FILE_REF:
        print(f'No change needed: workspace already contains {FILE_REF}')
        sys.exit(0)

new_ref = ET.Element('FileRef')
new_ref.set('location', FILE_REF)
root.append(new_ref)

ET.indent(root, space='   ')
new_xml = ET.tostring(root, encoding='unicode')
if not new_xml.startswith('<?xml'):
    new_xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + new_xml
new_xml += '\n'

backup = WORKSPACE.with_suffix('.xcworkspacedata.bak')
backup.write_text(xml_text)
WORKSPACE.write_text(new_xml)

print(f'Added {FILE_REF} to {WORKSPACE}')
print(f'Backup written to {backup}')

print('\nCurrent workspace file refs:')
for ref in root.findall('FileRef'):
    print(' -', ref.attrib.get('location'))
