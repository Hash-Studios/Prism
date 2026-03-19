import type { ReactNode } from "react";

type BadgeProps = {
  children: ReactNode;
  subtle?: boolean;
};

export function Badge({ children, subtle = false }: BadgeProps) {
  return (
    <span
      className={
        subtle
          ? "inline-flex items-center rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-medium text-white/80"
          : "inline-flex items-center rounded-full border border-accent/35 bg-accent/10 px-3 py-1 text-xs font-semibold text-accent"
      }
    >
      {children}
    </span>
  );
}
