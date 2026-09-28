# project agent rules

## database safety

- run all tests, smoke checks, seed scripts, and manual verification against a local or separate test database.
- never use the live production database for testing or verification.
- production writes require an explicit release or operations task, not a test shortcut.

## release banners

- every release must include a short human-language update message in Indonesian or the user's language.
- describe what users will notice, using playful natural wording when appropriate.
- avoid robotic implementation jargon, upstream references, internal version details, and commit-style changelogs.
- if a release contains only bug fixes, use a plain message such as: "Hanya bug fixes saja hehe".

## releasing the app

- always release with `mobile/scripts/release.sh "<release notes>"`, never with a hand-typed `flutter build`. use `--dry-run` to build and check without publishing.
- the script passes `--dart-define=API_BASE` itself and refuses to publish an apk that still points at the emulator (`10.0.2.2`), lacks the backend address, or is signed with a key other than the one every release uses.
- why: v2.1.0 was built without `API_BASE` and shipped pointing at the emulator. on every real phone it loaded forever, until v2.1.1 replaced it.
- a wrong signing key is just as bad: the update cannot install over the existing app, so users would have to uninstall and lose closings not yet synced.
