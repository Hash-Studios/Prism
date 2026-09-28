# Domain docs

How the engineering skills should read this repo's domain documentation.

This repo is **single-context**.

## Before exploring, read these

- **`.impeccable.md`** at the repo root: users, brand, themes, design principles, and key implementation references.
- **`README.md`**: the product feature list.
- **`CLAUDE.md`** and **`AGENTS.md`**: architecture, commands, and working rules.

If a file does not exist, **proceed silently**. Do not flag its absence and do not suggest creating it. The `/domain-modeling` skill creates a `CONTEXT.md` lazily when terms or decisions get resolved.

## File structure

```
/
├── .impeccable.md
├── lib/            app: core/ infrastructure, features/<name>/ modules
├── functions/      Firebase Cloud Functions (TypeScript)
├── web/            Next.js site
└── firestore.rules, firestore.indexes.json
```

If this becomes multi-context, add a root `CONTEXT-MAP.md` that points at one `CONTEXT.md` per context (for example `functions/CONTEXT.md`), each with its own `docs/adr/`.

## Use the product vocabulary

Use the terms the app uses: **wall** (wallpaper), **setup** (home-screen setup), **Prism Coins**, **Prism Premium**, **streak**, **Wall of the Day (WOTD)**, **collection**, **creator**. Do not drift to synonyms in issue titles, test names, or proposals.
