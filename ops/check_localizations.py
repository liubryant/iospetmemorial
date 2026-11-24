#!/usr/bin/env python3
"""Offline resource audit. No network requests or user data reads."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / 'PetMemorial' / 'Localization'
languages = {'zh-Hans', 'en', 'ja', 'de', 'fr', 'es', 'zh-Hant-HK', 'ko', 'ar'}
pattern = re.compile(r'\{\d+\}|%[.\d]*[df]')
catalog = json.loads((folder / 'Localizable.xcstrings').read_text())['strings']
for key, entry in catalog.items():
    assert set(entry['localizations']) == languages, key
    tokens = sorted(pattern.findall(key))
    for language, translation in entry['localizations'].items():
        value = translation['stringUnit']['value']
        assert value.strip(), (key, language)
        assert sorted(pattern.findall(value)) == tokens, (key, language, 'format tokens')
        if language in {'en', 'de', 'fr', 'es', 'ko', 'ar'}:
            assert not re.search('[\u4e00-\u9fff]', value), (key, language, 'untranslated Chinese')
for source in (root / 'PetMemorial').glob('*.swift'):
    for match in re.finditer(r'\bL\(("(?:[^"\\]|\\.)*")', source.read_text()):
        assert json.loads(match[1]) in catalog, (source.name, match[1])
info = json.loads((folder / 'InfoPlist.xcstrings').read_text())['strings']
assert set(info['CFBundleDisplayName']['localizations']) == languages
print(f'Validated {len(catalog)} UI keys and app names in {len(languages)} languages.')
