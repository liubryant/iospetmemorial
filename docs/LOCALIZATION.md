# Application languages

The app supports Simplified Chinese (`zh-Hans`), English (`en`), Japanese (`ja`), German (`de`), French (`fr`), Spanish (`es`), Hong Kong Traditional Chinese (`zh-Hant-HK`), Korean (`ko`), and Arabic (`ar`). It follows iOS's per-app preferred language, with English as the development fallback. Me → Language opens the app's system settings. Changing the language relaunches the app through iOS; there is no independent language preference that could disagree with system dialogs or RealityKit signs.

`PetMemorial/Localization/Localizable.xcstrings` contains fixed UI copy, notices, notification templates, shared-garden responses, and 3D destination names. `InfoPlist.xcstrings` provides localized home-screen names. `L` returns a localized String before SwiftUI, UIKit, RealityKit or notifications consume it. Indexed `{0}` arguments support language-specific word order and are substituted once, leaving user-authored tokens untouched.

Pet names, stories, letters, captions and public memorial content remain in their original language. Species (`cat`/`dog`), avatar/theme IDs, account keys and API payloads do not change with language. Phone authentication still uses the existing mainland China phone service; localization does not add international SMS support. Arabic/Persian/full-width input digits are normalized for the existing API. Phone, code and password fields keep left-to-right input while the surrounding app follows Arabic right-to-left layout.

Town and forest signs fit their available widths. Header text scales where appropriate; longer explanatory text wraps or scrolls. Legal document links stay outside the scrolling consent description. The standalone agreement/privacy HTML documents and server-rendered shared pages retain their original content; this change localizes the app UI and consent dialog, not those H5 documents.

## Verification

Run `python3 ops/check_localizations.py` for language coverage, missing keys, untranslated Chinese and placeholder consistency. Unit tests cover literal user values, argument reordering, digit conversion and packaged resources. `LocalizationUITests` checks all nine languages across consent, home, photos, letters, settings and both login modes, verifies Arabic tab direction, and captures English/German/Arabic town, map and forest screens. These tests do not send SMS or upload content. SDK startup remains disabled in test launches.

Translate new fixed copy in all nine locales and use `L` only at fixed-copy boundaries. Never apply lookup to arbitrary user-authored text. The server visitor label is a fixed server label (self or anonymous visitor), not a user-chosen nickname. Translation drafts were generated externally with explicit user authorization and key UI terms were edited; future terminology should stay consistent with this catalog.
