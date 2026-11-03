#!/usr/bin/env python3
"""Attach the Play-signed universal APK and its SHA-256 to a Prism GitHub release.

See docs/features/public-apk.md. Run through `make public-apk TAG=v<version>+<code> [DRY_RUN=1]`.
"""

import argparse
import base64
import binascii
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import threading
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'com.hash.prism'
REPO = 'Hash-Studios/Prism'
# Play Console > Test and release > App integrity > App signing key certificate > SHA-256, as lowercase hex.
PLAY_APP_SIGNING_CERT_SHA256 = ''
DEFAULT_CREDENTIALS = ROOT / 'android/google-play-console.json'
PUBLISHER_API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications'
SCOPE = 'https://www.googleapis.com/auth/androidpublisher'


class ReleaseError(Exception):
    pass


@dataclass(frozen=True)
class Tag:
    version: str
    code: int

    @property
    def name(self) -> str:
        return f'v{self.version}+{self.code}'

    @property
    def apk_name(self) -> str:
        return f'prism-{self.version}-{self.code}.apk'

    @property
    def sha_name(self) -> str:
        return f'{self.apk_name}.sha256'


@dataclass(frozen=True)
class Tools:
    apksigner: Path
    aapt2: Path


def parse_tag(text: str) -> Tag:
    match = re.fullmatch(r'v(\d+\.\d+\.\d+)\+(\d+)', text)
    if not match:
        raise ReleaseError(f'Tag {text!r} is not v<major>.<minor>.<patch>+<code>.')
    return Tag(match.group(1), int(match.group(2)))


def normalize_sha256(value: str) -> str:
    """Accepts hex (with or without colons) or base64, as Play Console and the API print it."""
    compact = value.strip().replace(':', '')
    if re.fullmatch(r'[0-9a-fA-F]{64}', compact):
        return compact.lower()
    try:
        raw = base64.b64decode(value.strip() + '=' * (-len(value.strip()) % 4), altchars=b'-_', validate=False)
    except (binascii.Error, ValueError):
        raw = b''
    if len(raw) == 32:
        return raw.hex()
    raise ReleaseError('Invalid SHA-256 certificate digest.')


def signer_digests(apksigner_output: str) -> set[str]:
    return {d.lower() for d in re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]{64})', apksigner_output)}


def badging(aapt2_output: str) -> tuple[str, int, str]:
    match = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']*)'",
                      aapt2_output, re.MULTILINE)
    if not match:
        raise ReleaseError('aapt2 did not print the package name, version code and version name.')
    return match.group(1), int(match.group(2)), match.group(3)


def find_tools() -> Tools:
    homes = [os.environ.get('ANDROID_HOME'), os.environ.get('ANDROID_SDK_ROOT'),
             str(Path.home() / 'Library/Android/sdk'), str(Path.home() / 'Android/Sdk')]
    for home in filter(None, homes):
        build_tools = Path(home) / 'build-tools'
        if not build_tools.is_dir():
            continue
        versions = sorted((p for p in build_tools.iterdir() if (p / 'apksigner').exists() and (p / 'aapt2').exists()),
                          key=lambda p: [int(n) if n.isdigit() else 0 for n in re.split(r'[.-]', p.name)])
        if versions:
            return Tools(versions[-1] / 'apksigner', versions[-1] / 'aapt2')
    raise ReleaseError('Android build-tools with apksigner and aapt2 not found. Set ANDROID_HOME.')


def run(cmd: list[str], *, what: str) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        raise ReleaseError(f'{what} failed: {detail[-1] if detail else f"exit {result.returncode}"}')
    return result.stdout


def check_apk(apk: Path, tag: Tag, expected_cert: str | None, tools: Tools) -> str:
    """Returns the signing certificate SHA-256. Raises unless the APK is this release, signed by one expected key."""
    output = run([str(tools.apksigner), 'verify', '--verbose', '--print-certs', str(apk)],
                 what='apksigner verify')
    signer_count = re.findall(r'^Number of signers: (\d+)$', output, re.MULTILINE)
    digests = signer_digests(output)
    if signer_count != ['1'] or len(digests) != 1:
        actual = signer_count[0] if len(signer_count) == 1 else str(len(digests))
        raise ReleaseError(f'APK has {actual} signing certificates, expected exactly 1.')
    cert = digests.pop()
    if expected_cert is not None and cert != expected_cert:
        raise ReleaseError(f'APK is signed by certificate {cert}, expected the Play app signing certificate '
                           f'{expected_cert}.')
    package, code, version = badging(run([str(tools.aapt2), 'dump', 'badging', str(apk)],
                                         what='aapt2 dump badging'))
    if package != PACKAGE:
        raise ReleaseError(f'APK package is {package}, expected {PACKAGE}.')
    if code != tag.code:
        raise ReleaseError(f'APK version code is {code}, expected {tag.code}.')
    if version != tag.version:
        raise ReleaseError(f'APK version is {version!r}, expected {tag.version}.')
    return cert


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def write_sha_file(apk: Path, sha_name: str) -> Path:
    target = apk.with_name(sha_name)
    target.write_text(f'{sha256_file(apk)}  {apk.name}\n')
    return target


def load_service_account(path: Path) -> dict[str, str]:
    try:
        data = json.loads(path.read_text())
    except FileNotFoundError:
        raise ReleaseError(f'Play credentials not found at {path}. Set PLAY_SERVICE_ACCOUNT_JSON or pass --apk.') from None
    except (OSError, ValueError):
        raise ReleaseError(f'Play credentials at {path} are not readable JSON.') from None
    if data.get('type') != 'service_account' or not all(
            isinstance(data.get(k), str) and data[k] for k in ('client_email', 'private_key')):
        raise ReleaseError(f'Play credentials at {path} are not a service account key.')
    return {'client_email': data['client_email'], 'private_key': data['private_key'],
            'token_uri': data.get('token_uri') or 'https://oauth2.googleapis.com/token'}


def sign_rs256(message: bytes, private_key_pem: str) -> bytes:
    """Signs with openssl. The key goes through a pipe, never to disk or argv."""
    try:
        read_fd, write_fd = os.pipe()
    except Exception:
        raise ReleaseError('Could not open the service account signing pipe.') from None
    writer_failed = []

    def write_key():
        try:
            with os.fdopen(write_fd, 'wb') as pipe:
                pipe.write(private_key_pem.encode())
        except Exception:
            writer_failed.append(True)

    writer = threading.Thread(target=write_key, daemon=True)
    try:
        writer.start()
        result = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', f'/dev/fd/{read_fd}'], input=message,
                                capture_output=True, pass_fds=(read_fd,))
    except Exception:
        raise ReleaseError('openssl could not sign the token request with the service account key.') from None
    finally:
        os.close(read_fd)
        if writer.ident is None:
            os.close(write_fd)
        else:
            writer.join()
    if writer_failed or result.returncode != 0 or not result.stdout:
        raise ReleaseError('openssl could not sign the token request with the service account key.')
    return result.stdout


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def google_error(error: urllib.error.HTTPError) -> str:
    """Response bodies can echo credentials or bearer tokens. Report only the status."""
    return f'HTTP {error.code}'


def access_token(account: dict[str, str]) -> str:
    try:
        now = int(time.time())
        header = _b64url(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode())
        claims = _b64url(json.dumps({'iss': account['client_email'], 'scope': SCOPE, 'aud': account['token_uri'],
                                     'iat': now, 'exp': now + 600}).encode())
        signing_input = f'{header}.{claims}'.encode()
        assertion = f'{header}.{claims}.{_b64url(sign_rs256(signing_input, account["private_key"]))}'
        body = urllib.parse.urlencode({'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                                       'assertion': assertion}).encode()
        with urllib.request.urlopen(urllib.request.Request(account['token_uri'], data=body), timeout=30) as response:
            token = json.loads(response.read()).get('access_token')
    except urllib.error.HTTPError as error:
        raise ReleaseError(f'Play token request refused: {google_error(error)}') from None
    except Exception:
        raise ReleaseError('Play token request failed.') from None
    if not isinstance(token, str) or not token:
        raise ReleaseError('Play token response had no access token.')
    return token


def play_get(url: str, token: str, *, what: str):
    try:
        request = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
        return urllib.request.urlopen(request, timeout=300)
    except urllib.error.HTTPError as error:
        raise ReleaseError(f'{what} refused: {google_error(error)}') from None
    except Exception:
        raise ReleaseError(f'{what} failed.') from None


def pick_universal_apk(listing: dict, expected_cert: str | None) -> tuple[str, str]:
    """Returns (downloadId, certificate SHA-256) of the universal APK for the expected signing key."""
    keys = listing.get('generatedApks') or []
    candidates = [(normalize_sha256(k['certificateSha256Hash']), k) for k in keys if k.get('certificateSha256Hash')]
    if expected_cert is not None:
        candidates = [c for c in candidates if c[0] == expected_cert]
    if len(candidates) != 1:
        found = ', '.join(c for c, _ in candidates) or 'none'
        raise ReleaseError(f'Expected one generated APK set for the Play signing key, found {len(candidates)} ({found}).')
    cert, entry = candidates[0]
    download_id = (entry.get('generatedUniversalApk') or {}).get('downloadId')
    if not download_id:
        raise ReleaseError('Play did not generate a universal APK for this version code.')
    return download_id, cert


def download_play_apk(tag: Tag, credentials: Path, expected_cert: str | None, target: Path) -> str:
    """Downloads the universal APK into target. Returns the certificate SHA-256 that Play reports for it."""
    partial = target.with_name(target.name + '.part')
    try:
        token = access_token(load_service_account(credentials))
        base = f'{PUBLISHER_API}/{PACKAGE}/generatedApks/{tag.code}'
        with play_get(base, token, what='Listing generated APKs') as response:
            listing = json.loads(response.read())
        download_id, cert = pick_universal_apk(listing, expected_cert)
        url = f'{base}/downloads/{urllib.parse.quote(download_id, safe="")}:download?alt=media'
        with play_get(url, token, what='Downloading the universal APK') as response, partial.open('wb') as out:
            shutil.copyfileobj(response, out, 1 << 20)
            length = response.headers.get('Content-Length')
            if length is not None and out.tell() != int(length):
                raise ReleaseError('The universal APK download was incomplete.')
        partial.replace(target)
        return cert
    except ReleaseError:
        raise
    except Exception:
        raise ReleaseError('Could not download the universal APK.') from None
    finally:
        partial.unlink(missing_ok=True)


def release_assets(tag: Tag) -> set[str]:
    out = run(['gh', 'release', 'view', tag.name, '--repo', REPO, '--json', 'assets'],
              what=f'Reading GitHub release {tag.name}')
    return {a['name'] for a in json.loads(out)['assets']}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--tag', required=True, help="the GitHub release tag, for example 'v3.18.2+359'")
    parser.add_argument('--dry-run', action='store_true', help='download and check, but attach nothing')
    parser.add_argument('--apk', type=Path, help='check this APK instead of downloading it from Play')
    parser.add_argument('--expected-cert', help='dry run only: the certificate SHA-256 to check against')
    parser.add_argument('--out-dir', type=Path, default=ROOT / 'build/public-apk')
    args = parser.parse_args(argv)

    try:
        tag = parse_tag(args.tag)
        pinned = normalize_sha256(PLAY_APP_SIGNING_CERT_SHA256) if PLAY_APP_SIGNING_CERT_SHA256 else None
        override = normalize_sha256(args.expected_cert) if args.expected_cert else None
        if args.dry_run:
            expected = override or pinned
        else:
            if pinned is None:
                raise ReleaseError('PLAY_APP_SIGNING_CERT_SHA256 is not set in tool/public_apk.py. '
                                   'Copy it from Play Console > App integrity, then run again.')
            if args.expected_cert is not None:
                raise ReleaseError('--expected-cert is for dry runs. A real attach checks only the pinned certificate.')
            expected = pinned
        tools = find_tools()

        assets = release_assets(tag)
        present = {tag.apk_name, tag.sha_name} & assets
        if len(present) == 2:
            print(f'{tag.name} already has {tag.apk_name} and {tag.sha_name}. Nothing to do.')
            return 0
        if present:
            raise ReleaseError(f'{tag.name} has only {present.pop()}. Remove it in GitHub, then run again.')
        print(f'GitHub release {tag.name} found. It has no APK yet.')

        args.out_dir.mkdir(parents=True, exist_ok=True)
        apk = args.out_dir / tag.apk_name
        if args.apk:
            shutil.copyfile(args.apk, apk)
            print(f'Checking local APK {args.apk}.')
        else:
            credentials = Path(os.environ.get('PLAY_SERVICE_ACCOUNT_JSON') or DEFAULT_CREDENTIALS)
            print(f'Downloading the Play universal APK for version code {tag.code} (credentials: {credentials}).')
            reported = download_play_apk(tag, credentials, expected, apk)
            expected = expected or reported

        cert = check_apk(apk, tag, expected, tools)
        sha_file = write_sha_file(apk, tag.sha_name)
        print(f'APK:         {apk} ({apk.stat().st_size} bytes)')
        print(f'SHA-256:     {sha_file.read_text().split()[0]} ({sha_file})')
        print(f'Signed by:   {cert}')
        if expected is None:
            print('Pin:         PLAY_APP_SIGNING_CERT_SHA256 is not set. Compare the certificate above with Play Console '
                  'before the first real attach.')
        upload = ['gh', 'release', 'upload', tag.name, str(apk), str(sha_file), '--repo', REPO]
        if args.dry_run:
            print(f'Dry run:     attached nothing. A real run uploads: {" ".join(upload)}')
            return 0
        run(upload, what='gh release upload')
        print(f'Attached {tag.apk_name} and {tag.sha_name} to {tag.name}.')
        return 0
    except ReleaseError as error:
        print(f'public_apk: {error}', file=sys.stderr)
        return 1
    except Exception as error:
        print(f'public_apk: failed with {type(error).__name__}. No release assets were confirmed attached.',
              file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
