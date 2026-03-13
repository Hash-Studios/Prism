type SectionHeadingProps = {
  kicker?: string;
  title: string;
  description?: string;
  centered?: boolean;
};

export function SectionHeading({
  kicker,
  title,
  description,
  centered = false,
}: SectionHeadingProps) {
  return (
    <div className={centered ? "mx-auto max-w-3xl text-center" : "max-w-3xl"}>
      {kicker ? (
        <p className="mb-3 text-xs font-semibold uppercase tracking-[0.22em] text-accent">
          {kicker}
        </p>
      ) : null}
      <h2 className="text-balance text-3xl font-bold tracking-tight text-white sm:text-4xl">
        {title}
      </h2>
      {description ? (
        <p className="mt-4 text-pretty text-base leading-relaxed text-white/70">
          {description}
        </p>
      ) : null}
    </div>
  );
}
