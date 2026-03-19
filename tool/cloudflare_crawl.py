#!/usr/bin/env python3
"""Start a Cloudflare crawl job, poll until completion, then fetch records.

Usage:
  python3 tool/cloudflare_crawl.py "https://x.com/HashStudiosIN"

Required environment variables:
  CF_ACCOUNT_ID
  CF_API_TOKEN
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


TERMINAL_STATUSES = {
    "completed",
    "errored",
    "cancelled_due_to_timeout",
    "cancelled_due_to_limits",
    "cancelled_by_user",
}


class ApiRequestError(RuntimeError):
    def __init__(self, status_code: int, body: str):
        super().__init__(f"HTTP {status_code}: {body}")
        self.status_code = status_code
        self.body = body


def make_request(url: str, token: str, method: str = "GET", body: dict | None = None) -> dict:
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")

    request = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            content = response.read().decode("utf-8")
            return json.loads(content)
    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode("utf-8", errors="replace")
        raise ApiRequestError(exc.code, error_body) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Request failed: {exc.reason}") from exc


def start_job(base_url: str, token: str, payload: dict) -> str:
    response = make_request(base_url, token, method="POST", body=payload)
    if not response.get("success"):
        raise RuntimeError(f"Failed to start crawl: {json.dumps(response, indent=2)}")
    return response["result"]


def wait_for_completion(base_url: str, token: str, job_id: str, interval: int, max_attempts: int) -> str:
    for attempt in range(1, max_attempts + 1):
        poll_url = f"{base_url}/{job_id}?limit=1"
        try:
            response = make_request(poll_url, token)
        except ApiRequestError as exc:
            if exc.status_code == 404 and '"code":1001' in exc.body and attempt <= 12:
                print(f"[{attempt}/{max_attempts}] status=job_pending")
                time.sleep(interval)
                continue
            raise

        if not response.get("success"):
            raise RuntimeError(f"Polling failed: {json.dumps(response, indent=2)}")

        status = response.get("result", {}).get("status", "unknown")
        print(f"[{attempt}/{max_attempts}] status={status}")

        if status in TERMINAL_STATUSES:
            return status

        time.sleep(interval)

    raise RuntimeError("Crawl job did not reach terminal status before timeout")


def fetch_records(base_url: str, token: str, job_id: str, record_limit: int, status_filter: str | None) -> list[dict]:
    records: list[dict] = []
    cursor: str | None = None

    while True:
        params = {"limit": str(record_limit)}
        if status_filter:
            params["status"] = status_filter
        if cursor:
            params["cursor"] = cursor

        query = urllib.parse.urlencode(params)
        url = f"{base_url}/{job_id}?{query}"
        response = make_request(url, token)
        if not response.get("success"):
            raise RuntimeError(f"Fetching results failed: {json.dumps(response, indent=2)}")

        result = response.get("result", {})
        records.extend(result.get("records", []))
        cursor = result.get("cursor")
        if not cursor:
            break

    return records


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cloudflare Browser Rendering crawl helper")
    parser.add_argument("url", nargs="?", help="Start URL to crawl")
    parser.add_argument("--url", dest="url_flag", help="Start URL to crawl (optional alias)")
    parser.add_argument("--limit", type=int, default=10, help="Max pages to crawl")
    parser.add_argument("--depth", type=int, default=1, help="Max crawl depth")
    parser.add_argument(
        "--formats",
        nargs="+",
        default=["markdown"],
        choices=["html", "markdown", "json"],
        help="Response formats",
    )
    parser.add_argument(
        "--source",
        default="links",
        choices=["all", "sitemaps", "links"],
        help="URL discovery source",
    )
    parser.add_argument("--poll-interval", type=int, default=5, help="Seconds between poll attempts")
    parser.add_argument("--max-attempts", type=int, default=120, help="Polling attempts before timeout")
    parser.add_argument("--record-limit", type=int, default=100, help="Records per result page")
    parser.add_argument(
        "--status-filter",
        default="all",
        choices=["all", "queued", "errored", "completed", "disallowed", "skipped", "cancelled"],
        help="Filter records by URL status (default: all)",
    )
    parser.add_argument(
        "--out",
        default="output.json",
        help="Output JSON file path",
    )
    args = parser.parse_args()

    if not args.url and not args.url_flag:
        parser.error("URL is required. Pass it as positional arg or --url.")

    if not args.url:
        args.url = args.url_flag

    return args


def main() -> int:
    args = parse_args()

    account_id = os.getenv("CF_ACCOUNT_ID")
    api_token = os.getenv("CF_API_TOKEN")

    if not account_id or not api_token:
        print("Missing required environment variables: CF_ACCOUNT_ID and CF_API_TOKEN", file=sys.stderr)
        return 1

    base_url = f"https://api.cloudflare.com/client/v4/accounts/{account_id}/browser-rendering/crawl"
    payload = {
        "url": args.url,
        "limit": args.limit,
        "depth": args.depth,
        "formats": args.formats,
        "source": args.source,
    }

    status_filter = None if args.status_filter == "all" else args.status_filter

    try:
        job_id = start_job(base_url, api_token, payload)
        print(f"job_id={job_id}")

        final_status = wait_for_completion(
            base_url,
            api_token,
            job_id,
            interval=args.poll_interval,
            max_attempts=args.max_attempts,
        )
        print(f"final_status={final_status}")

        records = fetch_records(
            base_url,
            api_token,
            job_id,
            record_limit=args.record_limit,
            status_filter=status_filter,
        )

        output = {
            "job_id": job_id,
            "status": final_status,
            "count": len(records),
            "records": records,
        }
        with open(args.out, "w", encoding="utf-8") as handle:
            json.dump(output, handle, indent=2)

        print(f"saved_records={len(records)}")
        print(f"output_file={args.out}")

        if len(records) == 0:
            print(
                "hint=no records returned. Try --status-filter disallowed or --status-filter skipped to inspect blocked/filtered URLs."
            )
        return 0
    except Exception as exc:  # pylint: disable=broad-except
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
