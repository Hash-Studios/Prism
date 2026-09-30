# find-unused allowlist notes

`tool/find_unused_allowlist.json` lists symbols that `tool/find_unused_code.dart` reports but that are kept on purpose. It is empty: the tool counts extension member use and same-file references, so extensions, adapters and test seams no longer show up as false positives.

Add an entry only for a real false positive, with the reason in this file. When a report lists new unused code, delete the code instead.
