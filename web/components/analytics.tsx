"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";
import { APP_STORE_URL, PLAY_STORE_URL } from "@/lib/site-config";

const campaignKeys = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"];
const pagePaths = new Set(["/", "/4k-wallpapers", "/about", "/amoled-wallpapers", "/changelog", "/collections",
  "/contact", "/developers", "/docs", "/download", "/iphone-duo-wallpapers", "/mcp",
  "/open-source-android-wallpaper-app", "/privacy", "/terms"]);
const changelogPage = /^\/changelog\/v\d+(?:-\d+){2,3}$/;
const apkFile = /\/prism-(\d+\.\d+\.\d+)-\d+\.apk$/;

function pagePath(pathname: string): string {
  const path = pathname.length > 1 ? pathname.replace(/\/+$/, "") : pathname;
  return pagePaths.has(path) || changelogPage.test(path) ? path : "other";
}

/** Public project token only. No account or private query data is sent. */
export function MarketingAnalytics() {
  const pathname = usePathname();
  useEffect(() => {
    const token = process.env.NEXT_PUBLIC_MIXPANEL_TOKEN;
    const privacy: Navigator & { globalPrivacyControl?: boolean } = navigator;
    if (!token || privacy.globalPrivacyControl === true || privacy.doNotTrack === "1") return;
    const path = pagePath(window.location.pathname);
    const campaign: Record<string, string> = {};
    const query = new URLSearchParams(window.location.search);
    for (const key of campaignKeys) {
      const value = query.get(key);
      if (value && /^[a-zA-Z0-9_. -]{1,100}$/.test(value)) campaign[key] = value;
    }
    const campaignKey = "prism_marketing_campaign";
    try {
      if (Object.keys(campaign).length > 0) {
        sessionStorage.setItem(campaignKey, JSON.stringify(campaign));
      } else {
        const saved: unknown = JSON.parse(sessionStorage.getItem(campaignKey) || "{}");
        if (typeof saved === "object" && saved !== null && !Array.isArray(saved)) {
          for (const [key, value] of Object.entries(saved)) {
            if (campaignKeys.includes(key) && typeof value === "string" && /^[a-zA-Z0-9_. -]{1,100}$/.test(value)) {
              campaign[key] = value;
            }
          }
        }
      }
    } catch {}
    const sessionKey = "prism_marketing_session";
    let distinctId = crypto.randomUUID();
    try {
      distinctId = sessionStorage.getItem(sessionKey) || distinctId;
      sessionStorage.setItem(sessionKey, distinctId);
    } catch {}
    const entryKey = "prism_marketing_entry";
    let entryPath = path;
    try {
      const saved = sessionStorage.getItem(entryKey);
      if (saved && (saved === "other" || pagePath(saved) === saved)) entryPath = saved;
      sessionStorage.setItem(entryKey, entryPath);
    } catch {}
    const track = (event: string, properties: Record<string, string> = {}) => {
      const data = JSON.stringify([{ event, properties: {
        token, distinct_id: distinctId, $insert_id: crypto.randomUUID(),
        path, entry_path: entryPath, ...campaign, ...properties,
      } }]);
      void fetch("https://api-js.mixpanel.com/track?ip=0", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: data, keepalive: true, credentials: "omit",
      }).catch(() => {});
    };
    track("web_landing_viewed");
    const click = (event: MouseEvent) => {
      if (!(event.target instanceof Element)) return;
      const link = event.target.closest("a");
      if (!link) return;
      if (link.href === PLAY_STORE_URL) track("web_store_clicked", { store: "google_play" });
      if (link.href === APP_STORE_URL) track("web_store_clicked", { store: "app_store" });
      if (link.href === `${window.location.origin}/download`) track("web_download_clicked");
      if (event.target.closest("[data-analytics-apk]")) {
        const version = apkFile.exec(link.href)?.[1];
        track("web_apk_clicked", version ? { target: "apk_file", apk_version: version } : { target: "releases_page" });
      }
    };
    const qr = (event: Event) => {
      if (!(event.target instanceof Element)) return;
      if (!event.target.closest("[data-analytics-qr]")) return;
      track("web_qr_viewed", { store: "google_play" });
    };
    document.addEventListener("click", click);
    document.addEventListener("prism:qr-revealed", qr);
    return () => {
      document.removeEventListener("click", click);
      document.removeEventListener("prism:qr-revealed", qr);
    };
  }, [pathname]);
  return null;
}
