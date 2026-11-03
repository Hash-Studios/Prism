"use client";

import { useEffect, useState } from "react";
import { Download } from "lucide-react";
import {
  type ApkRelease,
  LATEST_RELEASE_URL,
  RELEASES_URL,
  formatSize,
  getApkRelease,
} from "@/lib/apk-release";

type ReleaseState =
  | { kind: "loading" }
  | { kind: "ready"; release: ApkRelease }
  | { kind: "missing" }
  | { kind: "failed" };

function useApkRelease(): ReleaseState {
  const [state, setState] = useState<ReleaseState>({ kind: "loading" });

  useEffect(() => {
    let active = true;
    void getApkRelease().then((result) => {
      if (!active) return;
      if (result.release) setState({ kind: "ready", release: result.release });
      else setState({ kind: result.status === "missing" ? "missing" : "failed" });
    });
    return () => {
      active = false;
    };
  }, []);

  return state;
}

const actionBase =
  "inline-flex min-h-12 items-center justify-center gap-2.5 rounded-2xl px-5 py-3 text-base font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-neutral-100 dark:focus-visible:ring-offset-base-900";

export function PlayStoreIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinejoin="round"
      strokeLinecap="round"
      aria-hidden="true"
      className="size-5 shrink-0"
    >
      <polygon points="4,3.5 13,8.5 20.5,12 13,15.5 4,20.5 6,12" />
    </svg>
  );
}

export function ApkDownloadLink() {
  const state = useApkRelease();
  const release = state.kind === "ready" ? state.release : null;
  return (
    <a
      href={release?.url ?? LATEST_RELEASE_URL}
      className={`${actionBase} border border-neutral-300 bg-white text-black hover:bg-neutral-50 dark:border-white/15 dark:bg-white/5 dark:text-white dark:hover:bg-white/10`}
    >
      <Download aria-hidden="true" className="size-5 shrink-0" strokeWidth={1.75} />
      Download APK
      {release ? (
        <span className="font-normal text-neutral-500 tabular-nums dark:text-neutral-400">
          {formatSize(release.size)}
        </span>
      ) : null}
    </a>
  );
}

export function PlayStoreLink({ href }: { href: string }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`${actionBase} bg-accent text-white shadow-lg shadow-accent/30 hover:bg-accent-dark`}
    >
      <PlayStoreIcon />
      Get it on Google Play
    </a>
  );
}

function Row({ term, children }: { term: string; children: React.ReactNode }) {
  return (
    <div className="grid gap-1 py-3 sm:grid-cols-[7rem_1fr] sm:gap-4">
      <dt className="text-sm text-neutral-500 dark:text-neutral-400">{term}</dt>
      <dd className="min-w-0 text-base text-black dark:text-white">{children}</dd>
    </div>
  );
}

export function ApkReleaseDetails() {
  const state = useApkRelease();
  return (
    <section
      aria-labelledby="apk-release-heading"
      className="rounded-3xl border border-neutral-200 bg-white p-5 sm:p-6 dark:border-white/10 dark:bg-white/5"
    >
      <h2 id="apk-release-heading" className="text-lg font-semibold text-black dark:text-white">
        Latest APK
      </h2>
      <div data-testid="apk-status" aria-live="polite" className="text-neutral-600 dark:text-neutral-300">
        {state.kind === "loading" ? <p className="mt-3">Checking the latest release…</p> : null}
        {state.kind === "failed" || state.kind === "missing" ? (
          <p className="mt-3">
            {state.kind === "failed" ? "Unable to load the latest release." : "No APK is available yet."}{" "}
            <a
              href={RELEASES_URL}
              className="font-semibold text-accent underline-offset-4 hover:underline focus-visible:underline"
            >
              See all releases on GitHub
            </a>
          </p>
        ) : null}
        {state.kind === "ready" ? (
          <dl data-testid="apk-details" className="mt-2 divide-y divide-neutral-200 dark:divide-white/10">
            <Row term="Version">
              <span className="tabular-nums">
                {state.release.version} ({state.release.code})
              </span>
            </Row>
            <Row term="Size">
              <span className="tabular-nums">{formatSize(state.release.size)}</span>
            </Row>
            <Row term="SHA-256">
              {state.release.sha256 ? (
                <code className="block break-all font-mono text-sm leading-relaxed">{state.release.sha256}</code>
              ) : state.release.shaFileUrl ? (
                <a href={state.release.shaFileUrl} className="font-semibold text-accent hover:underline">
                  Download the SHA-256 file
                </a>
              ) : (
                <span>Not published for this release</span>
              )}
            </Row>
            <Row term="Release">
              <a
                href={state.release.releaseUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="font-semibold text-accent underline-offset-4 hover:underline focus-visible:underline"
              >
                Release notes on GitHub
              </a>
            </Row>
          </dl>
        ) : null}
      </div>
    </section>
  );
}
