export type DropMood = "night" | "warm" | "cool" | "mixed";

const MOOD_OF_COLOR: Record<string, Exclude<DropMood, "mixed">> = {
  black: "night", grey: "night", purple: "night",
  red: "warm", orange: "warm", yellow: "warm", brown: "warm", pink: "warm",
  blue: "cool", teal: "cool", green: "cool", white: "cool",
};

/** Names per mood. A Drop takes the first one its recent Drops did not use. Keep at least 13 per mood: the planner skips the names of the last 12 Drops. */
export const DROP_NAMES: Record<DropMood, readonly string[]> = {
  night: ["After Hours", "Blue Hour", "Low Light", "Night Shift", "Small Hours", "Moonrise", "Dark Room", "Night Swim",
    "Neon Nights", "Starfall", "Deep Space", "Lights Out", "Midnight Oil"],
  warm: ["Golden Hour", "Slow Burn", "Late Sun", "Warm Front", "Ember Days", "Afterglow", "Heatwave", "Sun Drift",
    "Ember Glow", "Desert Bloom", "Sunset Strip", "Red Shift", "Honey Light"],
  cool: ["Cold Water", "Clear Skies", "Tidewater", "First Frost", "Open Air", "Sea Glass", "Still Water", "Fresh Air",
    "Deep Blue", "Glacier", "Rain Check", "Cold Front", "Green Room"],
  mixed: ["Field Notes", "Open Studio", "Mixed Light", "Color Study", "Daydream", "Free Range", "New Ground", "Wide Angle",
    "Free Form", "Side B", "Odd Hours", "Color Field", "Loose Change"],
};

/** Mood of a set of walls. `wallColors` holds each wall's `colors` field. */
export function dropMood(wallColors: unknown[]): DropMood {
  const score: Record<Exclude<DropMood, "mixed">, number> = {night: 0, warm: 0, cool: 0};
  for (const colors of wallColors) {
    if (!Array.isArray(colors)) continue;
    const known = colors.filter((id): id is string =>
      typeof id === "string" && Object.prototype.hasOwnProperty.call(MOOD_OF_COLOR, id));
    known.forEach((id, i) => {
      score[MOOD_OF_COLOR[id]] += i === 0 ? 2 : 1;
    });
  }
  const total = score.night + score.warm + score.cool;
  if (total === 0) return "mixed";
  const ranked = (Object.keys(score) as Array<Exclude<DropMood, "mixed">>)
    .sort((a, b) => score[b] - score[a]);
  const [top, next] = ranked;
  if (score[top] === score[next] || score[top] <= total * 0.4) return "mixed";
  return top;
}

/** Walks the mood's names from the seed and returns the first one not in `recentTitles`. */
export function pickDropName(mood: DropMood, recentTitles: readonly string[], seed: number): string {
  const names = DROP_NAMES[mood];
  const n = names.length;
  const start = ((seed % n) + n) % n;
  const used = new Set(recentTitles.map((title) => title.trim().toLowerCase()));
  for (let i = 0; i < n; i++) {
    const name = names[(start + i) % n];
    if (!used.has(name.toLowerCase())) return name;
  }
  return names[start];
}

/** NN from a "YYYY-WNN" week key, or 0 when the key does not match. */
export function isoWeekNumber(weekKey: string): number {
  const match = /^\d{4}-W(\d{2})$/.exec(weekKey);
  return match ? Number(match[1]) : 0;
}
