# find-unused allowlist notes

This allowlist tracks known `find_unused_code.dart` false positives that are currently kept intentionally.

## Why these appear unused
- Extension declarations used via implicit extension invocation (`value.someExtensionGetter`) do not require explicit references to the extension type name.
- Adapter/context extension declarations are consumed via extension members, not by extension type names.
- Some interfaces are test-facing (`MixpanelClient`) and are referenced from tests only.

## Owners
- Analytics + logging: mobile-platform
- Adapter/context extensions: app-foundation
- Wallpaper mappers/extensions: wallpapers
- Profile completeness extensions/widgets: growth

When any allowlisted symbol becomes truly removable, delete it from code and from `tool/find_unused_allowlist.json`.
