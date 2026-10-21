"use client";

import { useEffect, useId, useRef, useState, type ReactNode } from "react";
import { QrCode } from "lucide-react";

export function QrDisclosure({ children, className }: { children: ReactNode; className?: string }) {
  const [expanded, setExpanded] = useState(false);
  const panelId = useId();
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!expanded) return;
    root.current?.dispatchEvent(new CustomEvent("prism:qr-revealed", { bubbles: true }));
    const outside = (event: PointerEvent) => {
      if (event.target instanceof Node && !root.current?.contains(event.target)) setExpanded(false);
    };
    const escape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setExpanded(false);
    };
    document.addEventListener("pointerdown", outside);
    document.addEventListener("keydown", escape);
    return () => {
      document.removeEventListener("pointerdown", outside);
      document.removeEventListener("keydown", escape);
    };
  }, [expanded]);

  return (
    <div ref={root} className="relative inline-block" data-analytics-qr>
      <button type="button" className={className} aria-expanded={expanded} aria-controls={panelId}
        onClick={() => setExpanded((value) => !value)}>
        <QrCode className="w-5 h-5" aria-hidden="true" />
        Scan QR Code
      </button>
      <div id={panelId} hidden={!expanded} role="region" aria-label="Scan to download Prism for Android"
        className="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 z-50 bg-white rounded-2xl shadow-xl p-2">
        {children}
      </div>
    </div>
  );
}
