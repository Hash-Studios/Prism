#!/usr/bin/env python3
"""Reclaim disk from Prism git worktrees without removing the worktrees.

Deletes only regenerable build and dependency caches. The worktree, its branch,
and every file git tracks stay exactly where they are, so the next build refetches
instead of the worktree being lost.

Report by default; pass --apply to actually delete.
"""

from __future__ import annotations

import argparse
import errno
import json
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

# Regenerable caches, and the command that brings each back. Anything not on this
# list is never considered, no matter how large it is -- an allowlist fails closed,
# which is the property that matters when the tool's whole job is deleting things.
#
# NOTE: `functions/lib` itself is NOT a target. Its .js/.js.map files are
# committed (compiled output checked into git despite functions/.gitignore
# listing `lib/**/*.js`), so most of that directory is tracked, not cache.
# Only `functions/lib/__tests__` (compiled Jest output) is genuinely untracked
# build output -- see the tracked-file gate below for why this matters.
TARGETS: list[tuple[str, str]] = [
    ("build", "fvm flutter build"),
    (".dart_tool", "fvm flutter pub get"),
    ("packages/*/.dart_tool", "fvm flutter pub get"),
    ("coverage", "fvm flutter test --coverage"),
    ("ios/Pods", "cd ios && pod install"),
    ("ios/.symlinks", "fvm flutter pub get"),
    ("ios/Flutter/ephemeral", "fvm flutter build ios"),
    ("android/.gradle", "gradle build"),
    ("android/build", "gradle build"),
    ("android/app/build", "gradle build"),
    (".gradle", "gradle build"),
    ("functions/node_modules", "cd functions && npm ci"),
    ("functions/lib/__tests__", "cd functions && npm run build && npm test"),
    ("web/node_modules", "cd web && npm ci"),
    ("web/.next", "cd web && npm run build"),
]

# Never delete these, even if a glob somehow reaches them. Secrets and per-worktree
# config in Prism are hand-copied from the main checkout because Doppler is
# path-scoped and fails from a worktree -- deleting one costs real human time to
# restore, unlike everything above. lib/firebase_options.dart is a generated stub
# (see AGENTS.md) that analysis/tests/debug builds depend on; it is gitignored but
# not a "cache" and regenerating it for real needs `flutterfire configure`.
NEVER = (
    ".env",
    ".env.local",
    ".doppler.yaml",
    "key.properties",
    "key.jks",
    "google-services.json",
    "GoogleService-Info.plist",
    "AuthKey.p8",
    "sentry.properties",
    "firebase_options.dart",
    "google-play-console.json",
    "android_keys.zip",
    "gitkey.dart",
)

# File mtimes are a poor "is anyone using this?" signal here: `git worktree add` stamps
# every file at creation, so a worktree abandoned an hour after it was made looks exactly
# as fresh as one being built in right now. Branch state is what actually separates them.
# A merged branch, or one whose upstream is gone, is finished work -- nobody is going to
# build there again, so its caches are pure cost. Age survives only as an opt-in filter.
AGE_PROBES = ("", "lib", "test", "functions/src", "web/app", "docs")


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def worktrees(repo: str) -> list[dict]:
    out = run(["git", "-C", repo, "worktree", "list", "--porcelain"]).stdout
    trees, cur = [], {}
    for line in out.splitlines():
        if line.startswith("worktree "):
            if cur:
                trees.append(cur)
            cur = {"path": line[9:], "locked": False, "branch": None}
        elif line.startswith("branch "):
            cur["branch"] = line[7:].replace("refs/heads/", "")
        elif line.strip() == "locked" or line.startswith("locked "):
            cur["locked"] = True
    if cur:
        trees.append(cur)
    return trees


def finished_branches(repo: str, default_branch: str) -> tuple[set[str], set[str]]:
    """Branches already merged into the default branch, and those whose upstream is gone.

    Both mean the same thing for our purposes: that line of work is over, so its build
    caches will never be reused. Computed once against the shared repo rather than
    per-worktree, which keeps this cheap across many worktrees.
    """
    merged = set()
    for ref in ("origin/" + default_branch, default_branch):
        r = run(["git", "-C", repo, "branch", "--format=%(refname:short)", "--merged", ref])
        if r.returncode == 0:
            merged.update(b.strip() for b in r.stdout.splitlines() if b.strip())
            break
    gone = set()
    r = run(["git", "-C", repo, "for-each-ref", "--format=%(refname:short) %(upstream) %(upstream:track)",
             "refs/heads"])
    for line in r.stdout.splitlines():
        parts = line.split(" ", 2)
        # An upstream that was configured and then deleted is git's own "this shipped" marker.
        if len(parts) == 3 and parts[1] and "gone" in parts[2]:
            gone.add(parts[0])
    return merged, gone


def du_kb(path: str) -> int:
    r = run(["du", "-sk", path])
    try:
        return int(r.stdout.split()[0])
    except (IndexError, ValueError):
        return 0


def newest_mtime(wt: str) -> float:
    newest = 0.0
    for probe in AGE_PROBES:
        p = os.path.join(wt, probe) if probe else wt
        try:
            newest = max(newest, os.stat(p).st_mtime)
        except OSError:
            continue
    return newest


def ignored(repo_wt: str, rel: str) -> bool:
    """Ask git whether this path is disposable, instead of trusting the allowlist alone.

    A path the repo does not declare ignored may be someone's real work, so the
    allowlist and git have to agree before anything is removed. This also surfaces
    gitignore gaps rather than papering over them.
    """
    return run(["git", "-C", repo_wt, "check-ignore", "-q", rel]).returncode == 0


def tracked_files_under(repo_wt: str, rel: str) -> list[str]:
    """Any committed files git already tracks under this path.

    Prism has at least one directory (`functions/lib`) where `.gitignore` lists a
    pattern that matches committed files -- the compiled `.js` output was force-added
    at some point despite `functions/.gitignore`. `check-ignore` alone would call
    those paths disposable. This is the second, independent gate: even a path git
    calls ignored is refused if git also has real tracked content inside it.
    """
    r = run(["git", "-C", repo_wt, "ls-files", "-z", "--", rel])
    return [f for f in r.stdout.split("\0") if f]


def expand(wt: str, pattern: str) -> list[str]:
    if "*" not in pattern:
        full = os.path.join(wt, pattern)
        return [pattern] if os.path.exists(full) else []
    head, _, tail = pattern.partition("/*/")
    base = os.path.join(wt, head)
    if not os.path.isdir(base):
        return []
    found = []
    for child in sorted(os.listdir(base)):
        rel = f"{head}/{child}/{tail}"
        if os.path.exists(os.path.join(wt, rel)):
            found.append(rel)
    return found


def scan_worktree(wt: str) -> tuple[list[tuple[str, int, str]], list[str], list[str]]:
    """Return (deletable [(rel, kb, restore_cmd)], skipped-because-not-ignored [rel], skipped-because-tracked [rel])."""
    deletable, not_ignored, tracked = [], [], []
    for pattern, restore in TARGETS:
        for rel in expand(wt, pattern):
            if os.path.basename(rel) in NEVER:
                continue
            full = os.path.join(wt, rel)
            # A symlink pointing outside the worktree must never be followed.
            if not os.path.realpath(full).startswith(os.path.realpath(wt) + os.sep):
                continue
            if not ignored(wt, rel):
                not_ignored.append(rel)
                continue
            tracked_hits = tracked_files_under(wt, rel)
            if tracked_hits:
                tracked.append(rel)
                continue
            kb = du_kb(full)
            if kb:
                deletable.append((rel, kb, restore))
    return deletable, not_ignored, tracked


def remove_path(full: str, attempts: int = 3) -> OSError | None:
    """Delete a cache path, retrying once or twice before giving up.

    Deleting a multi-gigabyte node_modules takes long enough that a build running in
    the same worktree can create a file inside a directory we already emptied, and
    rmtree then fails with ENOTEMPTY. A retry usually wins the race outright; when it
    does not, the caller reports the path as in use rather than as a failure, because
    a live build is a normal state here and not something to fix.
    """
    last: OSError | None = None
    for _ in range(attempts):
        try:
            if os.path.isdir(full) and not os.path.islink(full):
                shutil.rmtree(full)
            else:
                os.remove(full)
            return None
        except FileNotFoundError:
            return None
        except OSError as e:
            last = e
    return last


def human(kb: int) -> str:
    if kb >= 1024 * 1024:
        return f"{kb / 1024 / 1024:.2f} GB"
    if kb >= 1024:
        return f"{kb / 1024:.0f} MB"
    return f"{kb} KB"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", default=".", help="any Prism checkout or worktree (default: cwd)")
    ap.add_argument("--all", action="store_true",
                    help="every worktree, not just ones whose branch is merged or gone")
    ap.add_argument("--days", type=int, default=0, metavar="N",
                    help="with --all, also require the worktree to be untouched for N days")
    ap.add_argument("--default-branch", default="master", help="branch that 'merged' is measured against")
    ap.add_argument("--include-main", action="store_true", help="also sweep the main checkout (skipped by default)")
    ap.add_argument("--only", metavar="PATH", help="sweep just this one worktree, whatever its branch state")
    ap.add_argument("--apply", action="store_true", help="delete; without this the script only reports")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args()

    repo = os.path.realpath(args.repo)
    if run(["git", "-C", repo, "rev-parse", "--git-dir"]).returncode != 0:
        print(f"error: {repo} is not a git checkout", file=sys.stderr)
        return 2

    trees = worktrees(repo)
    main_path = os.path.realpath(trees[0]["path"]) if trees else None
    merged, gone = finished_branches(repo, args.default_branch)

    import time

    now = time.time()
    considered, skipped = [], []
    for t in trees:
        p = os.path.realpath(t["path"])
        if args.only and p != os.path.realpath(args.only):
            continue
        if not os.path.isdir(p):
            skipped.append((p, "missing"))
            continue
        if t["locked"]:
            skipped.append((p, "locked"))
            continue
        if p == main_path and not args.include_main and not args.only:
            skipped.append((p, "main checkout"))
            continue
        branch = t.get("branch")
        age_days = (now - newest_mtime(p)) / 86400
        why = "merged" if branch in merged else "upstream gone" if branch in gone else None
        if not args.only:
            if not why and not args.all:
                skipped.append((p, "branch still active"))
                continue
            if args.all and args.days and age_days < args.days:
                skipped.append((p, f"touched {age_days:.1f}d ago"))
                continue
        considered.append((p, age_days, branch, why or "--all"))

    with ThreadPoolExecutor(max_workers=8) as pool:
        scans = list(pool.map(lambda c: scan_worktree(c[0]), considered))

    rows, gitignore_gaps, tracked_gaps, total_kb = [], set(), set(), 0
    for (p, age_days, branch, why), (deletable, not_ignored, tracked) in zip(considered, scans):
        gitignore_gaps.update(not_ignored)
        tracked_gaps.update(os.path.join(p, r) for r in tracked)
        kb = sum(d[1] for d in deletable)
        if kb:
            rows.append({"path": p, "branch": branch, "reason": why, "age_days": round(age_days, 1),
                         "kb": kb, "items": [{"path": r, "kb": k, "restore": c} for r, k, c in deletable]})
            total_kb += kb
    rows.sort(key=lambda r: -r["kb"])

    freed_kb, failures, in_use = 0, [], []
    if args.apply:
        for row in rows:
            for item in row["items"]:
                full = os.path.join(row["path"], item["path"])
                err = remove_path(full)
                if err is None:
                    freed_kb += item["kb"]
                elif err.errno == errno.ENOTEMPTY:
                    # Something wrote into the tree while we were deleting it, which on a
                    # machine running many agents means a build is live in that worktree.
                    # Most of the tree is gone; the rest belongs to whoever is using it.
                    in_use.append(full)
                else:
                    failures.append(f"{full}: {err}")

    if args.json:
        print(json.dumps({"mode": "apply" if args.apply else "report", "total_kb": total_kb,
                          "freed_kb": freed_kb, "worktrees": rows,
                          "in_use": in_use,
                          "skipped": [{"path": p, "reason": r} for p, r in skipped],
                          "gitignore_gaps": sorted(gitignore_gaps),
                          "tracked_but_allowlisted": sorted(tracked_gaps),
                          "failures": failures}, indent=2))
        return 1 if failures else 0

    verb = "Freed" if args.apply else "Reclaimable"
    print(f"{verb}: {human(freed_kb if args.apply else total_kb)} across {len(rows)} worktrees "
          f"({len(considered)} considered, {len(skipped)} skipped)\n")
    for row in rows[:25]:
        print(f"{human(row['kb']):>10}  {row['path']}  [{row['reason']}]")
        for item in sorted(row["items"], key=lambda i: -i["kb"])[:4]:
            print(f"{human(item['kb']):>10}      {item['path']}")
    if len(rows) > 25:
        rest = sum(r["kb"] for r in rows[25:])
        print(f"{human(rest):>10}  ... and {len(rows) - 25} more worktrees")

    active = [s for s in skipped if s[1] == "branch still active"]
    if active:
        print(f"\nLeft alone: {len(active)} worktree(s) on branches still in flight. --all reaches them.")
    if gitignore_gaps:
        print("\nAllowlisted but not gitignored, so left in place:")
        for g in sorted(gitignore_gaps):
            print(f"  {g}")
        print("  Add a .gitignore rule if these should be sweepable.")
    if tracked_gaps:
        print("\nAllowlisted and gitignored, but git already tracks committed files under them"
              " -- left in place (never deletes tracked content):")
        for g in sorted(tracked_gaps):
            print(f"  {g}")
    if in_use:
        print(f"\n{len(in_use)} path(s) partly left behind, still being written to by a live build:")
        for u in in_use[:10]:
            print(f"  {u}")
        print("  Rerun once those builds finish to reclaim the remainder.")
    if failures:
        print(f"\n{len(failures)} failure(s):")
        for f in failures[:10]:
            print(f"  {f}")
    if not args.apply and total_kb:
        print("\nRerun with --apply to delete. Restore after: `fvm flutter pub get`, "
              "then `cd functions && npm ci` / `cd web && npm ci` as needed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
