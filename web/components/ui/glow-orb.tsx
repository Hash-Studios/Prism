import { cn } from "@/lib/utils";

type GlowOrbProps = {
  className?: string;
};

export function GlowOrb({ className }: GlowOrbProps) {
  return (
    <div
      aria-hidden="true"
      className={cn(
        "pointer-events-none absolute rounded-full bg-accent/30 blur-3xl",
        className,
      )}
    />
  );
}
