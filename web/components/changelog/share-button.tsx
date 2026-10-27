"use client";

import { Check, Link2 } from "lucide-react";
import { useState } from "react";
import { SITE_URL } from "@/lib/site-config";

export function ShareButton({ slug, version }: { slug: string; version: string }) {
  const url = `${SITE_URL}/changelog/${slug}`;
  const [copied, setCopied] = useState(false);

  const onClick = async () => {
    if (navigator.share) {
      try {
        await navigator.share({ title: `Prism ${version}`, url });
      } catch {}
      return;
    }
    await navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={copied ? "Link copied" : `Share ${version}`}
      title={copied ? "Link copied" : `Share ${version}`}
      className="inline-flex h-8 w-8 items-center justify-center rounded-full text-neutral-400 transition-colors hover:bg-white hover:text-black focus-visible:outline-2 focus-visible:outline-accent"
    >
      {copied ? <Check className="h-4 w-4" aria-hidden /> : <Link2 className="h-4 w-4" aria-hidden />}
    </button>
  );
}
