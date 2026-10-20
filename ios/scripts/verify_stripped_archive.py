#!/usr/bin/env python3
"""Compare an unsigned arm64 archive with its unstripped Xcode build products.

Usage: python3 ios/scripts/verify_stripped_archive.py AFTER.xcarchive BUILT_PRODUCTS_DIR
The comparison fails if SDK exports, UUIDs, machine code, or dSYMs change.
It does not prove distribution signing or physical-device behavior.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess


def macho(path):
    data = path.read_bytes()
    if data[:4] == b'\xca\xfe\xba\xbe':
        require(struct.unpack_from('>I', data, 4)[0] == 1, f'Expected an arm64-only build product: {path}')
        cpu, _, offset, length, _ = struct.unpack_from('>IIIII', data, 8)
        require(cpu == 0x100000c, f'Expected an arm64 slice: {path}')
        data = data[offset:offset + length]
    if data[:4] != b'\xcf\xfa\xed\xfe':
        raise ValueError(f'Expected a thin 64-bit Mach-O: {path}')
    result = {}
    pos = 32
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, size = struct.unpack_from('<II', data, pos)
        if command == 0x1b:  # LC_UUID
            result['uuid'] = data[pos + 8:pos + 24].hex()
        elif command == 0xb:  # LC_DYSYMTAB
            result['local_symbols'] = struct.unpack_from('<I', data, pos + 12)[0]
        elif command == 0x19:  # LC_SEGMENT_64
            for index in range(struct.unpack_from('<I', data, pos + 64)[0]):
                section = pos + 72 + index * 80
                if data[section:section + 16].rstrip(b'\0') == b'__text':
                    length, offset = struct.unpack_from('<QI', data, section + 40)
                    result['code_sha256'] = hashlib.sha256(data[offset:offset + length]).hexdigest()
        pos += size
    for key in ('uuid', 'code_sha256', 'local_symbols'):
        if key not in result:
            raise ValueError(f'Missing {key} in {path}')
    return result


def exports(path):
    return sorted(subprocess.check_output(['xcrun', 'nm', '-gjU', str(path)], text=True).splitlines())


def files(root):
    return {path.relative_to(root): path for path in root.rglob('*') if path.is_file() and not path.is_symlink()}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('products', type=Path)
    parser.add_argument('--baseline', type=Path, help='Optional older archive for total app size comparison')
    args = parser.parse_args()
    app = args.archive / 'Products/Applications/Runner.app'
    sources = {path.name: path for path in args.products.rglob('*.framework')
               if not any(part.endswith('.app') for part in path.parts)}
    require(sources, 'No unstripped build products found')
    results = []
    sdk_uuids = {}
    for framework in sorted((app / 'Frameworks').glob('*.framework')):
        before = sources[framework.name] / framework.stem
        after = framework / framework.stem
        relative = framework.relative_to(app) / framework.stem
        if framework.stem in ('App', 'Flutter'):
            require(before.read_bytes() == after.read_bytes(), f'{relative}: excluded binary changed')
            continue
        old, new = macho(before), macho(after)
        for key in ('uuid', 'code_sha256'):
            require(old[key] == new[key], f'{relative}: {key} changed')
        require(exports(before) == exports(after), f'{relative}: exports changed')
        sdk_uuids[framework.stem] = new['uuid']
        # strip -x retains private externals such as the linker radr marker.
        require(new['local_symbols'] <= old['local_symbols'], f'{relative}: local symbols increased')
        results.append(dict(name=framework.stem, before=before.stat().st_size, after=after.stat().st_size,
                            local_symbols_before=old['local_symbols'], local_symbols_after=new['local_symbols']))
    source_dsyms = {path.name: path for path in args.products.rglob('*.dSYM')}
    dsym_count = 0
    for dsym in (args.archive / 'dSYMs').glob('*.dSYM'):
        # Xcode numbers duplicate dSYM copies when it gathers native assets.
        source_name = re.sub(r' \d+(?=\.dSYM$)', '', dsym.name)
        old_files, new_files = files(source_dsyms[source_name]), files(dsym)
        require(old_files.keys() == new_files.keys(), f'dSYM inventory changed: {dsym.name}')
        for relative, before in old_files.items():
            require(before.read_bytes() == new_files[relative].read_bytes(), f'dSYM changed: {dsym.name}/{relative}')
        for dwarf in (dsym / 'Contents/Resources/DWARF').iterdir():
            if dwarf.name in sdk_uuids:
                uuid = subprocess.check_output(['xcrun', 'dwarfdump', '--uuid', str(dwarf)], text=True).split()[1]
                require(uuid.replace('-', '').lower() == sdk_uuids[dwarf.name], f'dSYM UUID mismatch: {dsym.name}')
        dsym_count += 1
    require(dsym_count > 0, 'No dSYMs checked')
    saved = sum(item['before'] - item['after'] for item in results)
    require(saved > 0, 'No SDK size reduction')
    require(sum(item['local_symbols_after'] for item in results) <
            sum(item['local_symbols_before'] for item in results), 'No local symbols removed')
    result = dict(saved_sdk_bytes=saved, frameworks=results, dsyms_unchanged=dsym_count)
    if args.baseline:
        baseline = args.baseline / 'Products/Applications/Runner.app'
        result['baseline_app_bytes'] = sum(path.stat().st_size for path in files(baseline).values())
        result['stripped_app_bytes'] = sum(path.stat().st_size for path in files(app).values())
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
