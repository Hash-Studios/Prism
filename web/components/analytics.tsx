"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";
import { APP_STORE_URL, PLAY_STORE_URL } from "@/lib/site-config";

const campaignKeys = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"];

/** Public project token only. No account or private query data is sent. */
export function MarketingAnalytics() {
  const pathname = usePathname();
  useEffect(() => {
    const token = process.env.NEXT_PUBLIC_MIXPANEL_TOKEN;
    if (!token) return;
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
    const track = (event: string, properties: Record<string, string> = {}) => {
      const data = JSON.stringify([{ event, properties: {
        token, distinct_id: distinctId, $insert_id: crypto.randomUUID(),
        path: window.location.pathname, ...campaign, ...properties,
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
      if (link?.href === PLAY_STORE_URL) track("web_store_clicked", { store: "google_play" });
      if (link?.href === APP_STORE_URL) track("web_store_clicked", { store: "app_store" });
    };
    let qrVisible = false;
    const qr = (event: Event) => {
      if (!(event.target instanceof Element)) return;
      if (!event.target.closest("[data-analytics-qr]")) return;
      if (qrVisible) return;
      qrVisible = true;
      track("web_qr_viewed", { store: "google_play" });
    };
    document.addEventListener("click", click);
    document.addEventListener("mouseover", qr);
    return () => {
      document.removeEventListener("click", click);
      document.removeEventListener("mouseover", qr);
    };
  }, [pathname]);
  return null;
}
