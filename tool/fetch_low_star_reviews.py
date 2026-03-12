#!/usr/bin/env python3

import argparse
import csv
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch 1/2-star Play Store reviews via gplay and sort by time."
    )
    parser.add_argument(
        "--package",
        default="com.hash.prism",
        help="Android package name (applicationId).",
    )
    parser.add_argument(
        "--stars",
        default="1,2",
        help="Comma-separated star ratings to include (e.g. 1,2).",
    )
    parser.add_argument(
        "--order",
        choices=("desc", "asc"),
        default="desc",
        help="Sort order by review lastModified timestamp.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Optional max number of reviews after sorting (0 = no limit).",
    )
    parser.add_argument(
        "--out-json",
        default="tmp/play_low_star_reviews.json",
        help="Output JSON file path.",
    )
    parser.add_argument(
        "--out-csv",
        default="tmp/play_low_star_reviews.csv",
        help="Output CSV file path.",
    )
    parser.add_argument(
        "--max-results",
        type=int,
        default=200,
        help="Max results per page for gplay reviews list.",
    )
    parser.add_argument(
        "--translation-language",
        default="",
        help="Optional translation language for reviews (e.g. en-US).",
    )
    return parser.parse_args()


def parse_star_filter(raw: str) -> set[int]:
    stars: set[int] = set()
    for part in raw.split(","):
        item = part.strip()
        if not item:
            continue
        value = int(item)
        if value < 1 or value > 5:
            raise ValueError(f"Invalid star value: {value}. Must be between 1 and 5.")
        stars.add(value)
    if not stars:
        raise ValueError("No valid stars provided.")
    return stars


def run_gplay_reviews(package: str, max_results: int, translation_language: str) -> Dict[str, Any]:
    command = [
        "gplay",
        "reviews",
        "list",
        "--package",
        package,
        "--paginate",
        "--max-results",
        str(max_results),
        "--output",
        "json",
    ]
    if translation_language:
        command.extend(["--translation-language", translation_language])

    proc = subprocess.run(command, capture_output=True, text=True)
    if proc.returncode != 0:
        message = proc.stderr.strip() or proc.stdout.strip() or "Unknown gplay error"
        raise RuntimeError(f"gplay reviews list failed: {message}")

    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Failed to parse gplay JSON output: {exc}") from exc


def last_modified_to_dt(last_modified: Optional[Dict[str, Any]]) -> Optional[datetime]:
    if not isinstance(last_modified, dict):
        return None

    seconds_raw = last_modified.get("seconds")
    nanos_raw = last_modified.get("nanos", 0)
    if seconds_raw is None:
        return None

    try:
        seconds = int(seconds_raw)
        nanos = int(nanos_raw)
    except (TypeError, ValueError):
        return None

    return datetime.fromtimestamp(seconds + (nanos / 1_000_000_000), tz=timezone.utc)


def extract_latest_user_comment(comments: Sequence[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    latest_comment: Optional[Dict[str, Any]] = None
    latest_time: Optional[datetime] = None

    for entry in comments:
        user_comment = entry.get("userComment") if isinstance(entry, dict) else None
        if not isinstance(user_comment, dict):
            continue

        ts = last_modified_to_dt(user_comment.get("lastModified"))
        if latest_comment is None:
            latest_comment = user_comment
            latest_time = ts
            continue
        if ts is not None and (latest_time is None or ts > latest_time):
            latest_comment = user_comment
            latest_time = ts

    return latest_comment


def extract_reviews(payload: Any) -> List[Dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if isinstance(payload, dict):
        reviews = payload.get("reviews", [])
        if isinstance(reviews, list):
            return [item for item in reviews if isinstance(item, dict)]
    return []


def flatten_reviews(payload: Any, stars: set[int]) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for review in extract_reviews(payload):

        user_comment = extract_latest_user_comment(review.get("comments", []))
        if not user_comment:
            continue

        star_rating = user_comment.get("starRating")
        if star_rating is None:
            continue
        try:
            star_value = int(star_rating)
        except (TypeError, ValueError):
            continue
        if star_value not in stars:
            continue

        dt = last_modified_to_dt(user_comment.get("lastModified"))
        rows.append(
            {
                "reviewId": review.get("reviewId", ""),
                "authorName": review.get("authorName", ""),
                "starRating": star_value,
                "appVersionCode": user_comment.get("appVersionCode"),
                "appVersionName": user_comment.get("appVersionName", ""),
                "reviewerLanguage": user_comment.get("reviewerLanguage", ""),
                "device": user_comment.get("device", ""),
                "androidOsVersion": user_comment.get("androidOsVersion"),
                "thumbsUpCount": user_comment.get("thumbsUpCount", 0),
                "thumbsDownCount": user_comment.get("thumbsDownCount", 0),
                "lastModifiedEpochSeconds": dt.timestamp() if dt else None,
                "lastModifiedUtc": dt.isoformat() if dt else "",
                "text": user_comment.get("text", ""),
            }
        )
    return rows


def write_json(path: Path, rows: List[Dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def write_csv(path: Path, rows: List[Dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "reviewId",
        "authorName",
        "starRating",
        "appVersionCode",
        "appVersionName",
        "reviewerLanguage",
        "device",
        "androidOsVersion",
        "thumbsUpCount",
        "thumbsDownCount",
        "lastModifiedEpochSeconds",
        "lastModifiedUtc",
        "text",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    args = parse_args()

    try:
        stars = parse_star_filter(args.stars)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    try:
        payload = run_gplay_reviews(
            package=args.package,
            max_results=args.max_results,
            translation_language=args.translation_language,
        )
        rows = flatten_reviews(payload, stars)
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    rows.sort(
        key=lambda item: (
            item["lastModifiedEpochSeconds"] is None,
            item["lastModifiedEpochSeconds"] or 0,
        ),
        reverse=(args.order == "desc"),
    )

    if args.limit and args.limit > 0:
        rows = rows[: args.limit]

    out_json = Path(args.out_json)
    out_csv = Path(args.out_csv)
    write_json(out_json, rows)
    write_csv(out_csv, rows)

    print(f"Fetched low-star reviews: {len(rows)}")
    print(f"Order: {'newest first' if args.order == 'desc' else 'oldest first'}")
    print(f"Wrote JSON: {out_json}")
    print(f"Wrote CSV:  {out_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
