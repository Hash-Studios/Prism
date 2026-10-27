"use client";

import { Check, Link2 } from "lucide-react";
import { useState } from "react";
import { shareLink } from "@/lib/share-link";
import { SITE_URL } from "@/lib/site-config";

export function ShareButton({ slug, version }: { slug: string; version: string }) {
  const url = `${SITE_URL}/changelog/${slug}`;
  const [result, setResult] = useState<"copied" | "failed" | null>(null);

  const onClick = async () => {
    const outcome = await shareLink(navigator, { title: `Prism ${version}`, url });
    if (outcome !== "copied" && outcome !== "failed") return;
    setResult(outcome);
    setTimeout(() => setResult(null), 2000);
  };

  const label = result === "copied" ? "Link copied" : result === "failed" ? "Couldn't copy the link" : `Share ${version}`;

  return (
    <>
      <button
        type="button"
        onClick={onClick}
        aria-label={label}
        title={label}
        className="inline-flex h-8 w-8 items-center justify-center rounded-full text-neutral-400 transition-colors hover:bg-white hover:text-black focus-visible:outline-2 focus-visible:outline-accent"
      >
        {result === "copied" ? <Check className="h-4 w-4" aria-hidden /> : <Link2 className="h-4 w-4" aria-hidden />}
      </button>
      <span role="status" className="text-sm text-neutral-500">
        {result === "failed" ? "Couldn't copy the link" : null}
      </span>
    </>
  );
}
