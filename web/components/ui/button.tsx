import Link from "next/link";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

type ButtonVariant = "primary" | "secondary" | "ghost";

type ButtonProps = {
  href: string;
  children: ReactNode;
  variant?: ButtonVariant;
  className?: string;
};

const variantClasses: Record<ButtonVariant, string> = {
  primary:
    "bg-accent text-white shadow-glow hover:bg-[#ef89a7] focus-visible:ring-accent/60",
  secondary:
    "border border-white/15 bg-white/5 text-white hover:bg-white/10 focus-visible:ring-accent/50",
  ghost: "text-white/80 hover:text-white focus-visible:ring-accent/50",
};

export function Button({
  href,
  children,
  variant = "primary",
  className,
}: ButtonProps) {
  return (
    <Link
      href={href}
      className={cn(
        "inline-flex items-center justify-center rounded-full px-5 py-2.5 text-sm font-semibold transition duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-base-900",
        variantClasses[variant],
        className,
      )}
    >
      {children}
    </Link>
  );
}
