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
