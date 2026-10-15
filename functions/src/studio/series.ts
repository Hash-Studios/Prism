/**
 * The art direction of Prism Studio. A series is a fixed style; a subject is one scene in that style; a palette
 * changes the colour of a scene. One prompt = subject + palette + series style + composition rules.
 */

export interface StudioSubject {
  /** Stable key. A subject is not used again for STUDIO_SUBJECT_COOLDOWN_DAYS. */
  id: string;
  title: string;
  prompt: string;
  tags: string[];
  /** One of the categories in wallCategory.ts. Overrides the series category. */
  category?: string;
}

export interface StudioPalette {
  id: string;
  /** Short name used in the wall title, for example "Ember". */
  name: string;
  prompt: string;
  tags: string[];
}

export interface StudioSeries {
  id: string;
  name: string;
  /** One of the categories in wallCategory.ts. */
  category: string;
  tags: string[];
  /** Style guide sent with every prompt of the series. */
  style: string;
  subjects: StudioSubject[];
  palettes: StudioPalette[];
}

export const STUDIO_SUBJECT_COOLDOWN_DAYS = 21;

/** Sent with every prompt. Keeps the clock area and the dock calm and keeps text and people out. */
export const STUDIO_COMPOSITION =
  "Vertical phone wallpaper, full bleed. The main subject sits in the middle third of the frame. " +
  "The top quarter and the bottom sixth are calm and low in detail, so a lock screen clock and app icons stay " +
  "readable. Crisp, clean detail, no clutter. The image contains no text, no letters, no numbers, no signature, " +
  "no watermark, no logo and no people.";

export const STUDIO_SERIES: StudioSeries[] = [
  {
    id: "after-dark",
    name: "After Dark",
    category: "Dark",
    tags: ["amoled", "dark"],
    style:
      "AMOLED wallpaper. Pure black background that fills most of the frame, one clear light source, deep shadows, " +
      "fine glowing detail against the black, cinematic and quiet.",
    subjects: [
      {id: "lone-lighthouse", title: "Lone Lighthouse", prompt: "a lone lighthouse on a black rock, its single beam cutting through night mist", tags: ["lighthouse", "night"]},
      {id: "orbit-ring", title: "Orbit Ring", prompt: "a thin glowing ring orbiting a dark planet seen edge on", tags: ["planet", "space"], category: "Space"},
      {id: "jellyfish-drift", title: "Jellyfish Drift", prompt: "a single bioluminescent jellyfish drifting in black water, trailing soft light", tags: ["jellyfish", "ocean"]},
      {id: "neon-staircase", title: "Neon Staircase", prompt: "a spiral staircase traced by one thin neon line, seen from below", tags: ["neon", "stairs"], category: "Neon"},
      {id: "moon-crescent", title: "Thin Crescent", prompt: "a razor thin crescent moon over a silent black sea with a faint reflection", tags: ["moon", "sea"], category: "Space"},
      {id: "firefly-field", title: "Firefly Field", prompt: "a few fireflies rising over tall grass silhouettes at night", tags: ["fireflies", "night"]},
      {id: "glass-orb", title: "Glass Orb", prompt: "a floating glass orb that holds a tiny glowing galaxy, resting in darkness", tags: ["orb", "galaxy"], category: "Galaxy"},
      {id: "aurora-ridge", title: "Aurora Ridge", prompt: "a narrow ribbon of aurora above a black mountain ridge", tags: ["aurora", "mountains"]},
      {id: "lantern-river", title: "Lantern River", prompt: "one paper lantern floating down a dark river, its light rippling on the water", tags: ["lantern", "river"]},
      {id: "comet-trail", title: "Comet Trail", prompt: "a comet with a long luminous tail crossing an empty black sky", tags: ["comet", "space"], category: "Space"},
      {id: "neon-koi", title: "Neon Koi", prompt: "a koi fish drawn in glowing light lines, swimming through black space", tags: ["koi", "neon"], category: "Neon"},
      {id: "eclipse", title: "Eclipse", prompt: "a total solar eclipse, a bright corona ring around a black disc", tags: ["eclipse", "sun"], category: "Space"},
      {id: "smoke-ribbon", title: "Smoke Ribbon", prompt: "a single ribbon of luminous smoke curling upward in darkness", tags: ["smoke", "abstract"]},
      {id: "night-tram", title: "Night Tram", prompt: "an empty night tram stop lit by one warm street lamp, everything else in shadow", tags: ["city", "night"]},
      {id: "crystal-cave", title: "Crystal Cave", prompt: "a cluster of crystals glowing from within at the bottom of a black cave", tags: ["crystals", "cave"]},
      {id: "satellite", title: "Lonely Satellite", prompt: "a small satellite with lit solar panels drifting above the curve of a dark earth", tags: ["satellite", "space"], category: "Space"},
      {id: "rain-window", title: "Rain Light", prompt: "rain drops on black glass catching one distant warm light", tags: ["rain", "bokeh"]},
      {id: "desert-stars", title: "Desert Stars", prompt: "a black desert dune line under a dense band of the milky way", tags: ["stars", "desert"], category: "Galaxy"},
      {id: "wire-flower", title: "Wire Flower", prompt: "a single flower made of thin glowing filaments on a black background", tags: ["flower", "light"], category: "Neon"},
      {id: "whale-glow", title: "Deep Whale", prompt: "the faint glowing outline of a whale gliding through the deep black ocean", tags: ["whale", "ocean"]},
    ],
    palettes: [
      {id: "ember", name: "Ember", prompt: "light in warm ember orange and gold", tags: ["orange"]},
      {id: "ice", name: "Ice", prompt: "light in cold ice blue and white", tags: ["blue"]},
      {id: "violet", name: "Violet", prompt: "light in violet and magenta", tags: ["purple"]},
      {id: "jade", name: "Jade", prompt: "light in jade green and teal", tags: ["green"]},
      {id: "crimson", name: "Crimson", prompt: "light in deep crimson red", tags: ["red"]},
      {id: "silver", name: "Silver", prompt: "light in soft silver monochrome", tags: ["monochrome"]},
    ],
  },
  {
    id: "quiet-architecture",
    name: "Quiet Architecture",
    category: "Architecture",
    tags: ["architecture", "calm"],
    style:
      "Minimal architectural photograph look. Clean geometric forms, soft natural light, smooth gradients in a large " +
      "empty sky, gentle shadows, wide negative space, calm and still.",
    subjects: [
      {id: "curved-wall", title: "Curved Wall", prompt: "a tall curved concrete wall rising into an empty sky", tags: ["concrete", "curves"]},
      {id: "white-stairs", title: "White Stairs", prompt: "white outdoor stairs climbing toward a single doorway", tags: ["stairs", "white"], category: "Minimal"},
      {id: "arch-colonnade", title: "Colonnade", prompt: "a row of slender arches casting long rhythmic shadows", tags: ["arches", "shadows"]},
      {id: "pool-pavilion", title: "Pool Pavilion", prompt: "a flat-roofed pavilion beside a still reflecting pool", tags: ["pool", "modern"]},
      {id: "spiral-tower", title: "Spiral Tower", prompt: "a spiral tower with ribbon balconies seen from directly below", tags: ["tower", "spiral"]},
      {id: "desert-house", title: "Desert House", prompt: "a small adobe house with one round window in an empty desert", tags: ["desert", "house"]},
      {id: "glass-bridge", title: "Glass Bridge", prompt: "a thin glass footbridge spanning two pale buildings high above", tags: ["bridge", "glass"]},
      {id: "lone-door", title: "The Door", prompt: "a single colored door set into a vast plain wall", tags: ["door", "wall"], category: "Minimal"},
      {id: "lighthouse-steps", title: "Harbor Steps", prompt: "wide stone steps leading down to a calm harbor and a small white lighthouse", tags: ["harbor", "steps"]},
      {id: "dome-roof", title: "Quiet Dome", prompt: "the smooth dome of an observatory against a clear sky", tags: ["dome", "observatory"]},
      {id: "balcony-grid", title: "Balcony Grid", prompt: "a facade of identical small balconies forming a soft repeating grid", tags: ["facade", "pattern"]},
      {id: "water-tower", title: "Water Tower", prompt: "a lone water tower on thin legs over a flat empty plain", tags: ["tower", "plain"]},
      {id: "cloister", title: "Cloister", prompt: "a sunlit cloister corridor with a small tree in the courtyard", tags: ["corridor", "courtyard"]},
      {id: "pier-cabin", title: "Pier Cabin", prompt: "a tiny wooden cabin at the end of a long pier over flat water", tags: ["pier", "cabin"]},
      {id: "chapel-snow", title: "Snow Chapel", prompt: "a small angular chapel alone on a snowy hill", tags: ["chapel", "snow"]},
      {id: "window-light", title: "Window Light", prompt: "a tall narrow window throwing a long shaft of light across an empty room", tags: ["interior", "light"], category: "Minimal"},
      {id: "terrace-garden", title: "Terrace", prompt: "a stepped terrace with a single olive tree and low white walls", tags: ["terrace", "olive"]},
      {id: "rotunda", title: "Rotunda", prompt: "the inside of a round rotunda looking up at a circular skylight", tags: ["rotunda", "skylight"]},
    ],
    palettes: [
      {id: "dawn", name: "Dawn", prompt: "pale peach and soft blue dawn light", tags: ["pastel"]},
      {id: "noon", name: "Noon", prompt: "bright white walls under a deep clear blue sky", tags: ["blue"]},
      {id: "terracotta", name: "Terracotta", prompt: "warm terracotta and sand tones", tags: ["warm"]},
      {id: "sage", name: "Sage", prompt: "muted sage green and cream tones", tags: ["green"]},
      {id: "dusk-rose", name: "Dusk Rose", prompt: "dusty rose and lilac dusk light", tags: ["pink"]},
      {id: "fog", name: "Fog", prompt: "soft grey fog and low contrast", tags: ["grey"]},
    ],
  },
  {
    id: "paper-worlds",
    name: "Paper Worlds",
    category: "Landscape",
    tags: ["illustration", "paper"],
    style:
      "Layered cut-paper illustration with a soft gouache texture. Stacked paper layers with gentle drop shadows " +
      "create depth, simple rounded shapes, handmade and warm, storybook calm.",
    subjects: [
      {id: "mountain-lake", title: "Mountain Lake", prompt: "layered mountains around a still lake with a tiny boat", tags: ["mountains", "lake"]},
      {id: "pine-valley", title: "Pine Valley", prompt: "a valley of layered pine forests with mist between the rows", tags: ["forest", "pines"], category: "Nature"},
      {id: "island-hut", title: "Island Hut", prompt: "a small island with one hut and a palm tree in a calm sea", tags: ["island", "sea"]},
      {id: "hot-air-balloon", title: "Balloon Morning", prompt: "a single hot air balloon floating over rolling hills", tags: ["balloon", "hills"]},
      {id: "desert-moon", title: "Desert Moon", prompt: "desert dunes in layers under a big round moon", tags: ["desert", "moon"]},
      {id: "waterfall", title: "Hidden Falls", prompt: "a narrow waterfall falling between layered green cliffs", tags: ["waterfall", "cliffs"], category: "Nature"},
      {id: "rice-terraces", title: "Rice Terraces", prompt: "curving rice terraces stepping down a hillside", tags: ["terraces", "fields"]},
      {id: "lighthouse-coast", title: "Coastline", prompt: "a rocky coastline with a small lighthouse and layered waves", tags: ["coast", "waves"], category: "Ocean"},
      {id: "snow-village", title: "Snow Village", prompt: "a tiny village of lit cottages in a snowy valley", tags: ["snow", "village"]},
      {id: "autumn-road", title: "Autumn Road", prompt: "a winding road through layered autumn hills and round trees", tags: ["autumn", "road"], category: "Nature"},
      {id: "underwater-reef", title: "Paper Reef", prompt: "a coral reef with layered seaweed and a few small fish", tags: ["reef", "underwater"], category: "Ocean"},
      {id: "night-train", title: "Night Train", prompt: "a small lit train crossing a long bridge over a dark valley", tags: ["train", "bridge"]},
      {id: "cherry-hill", title: "Blossom Hill", prompt: "a lone cherry blossom tree on a gentle hill", tags: ["blossom", "tree"], category: "Flowers"},
      {id: "canyon", title: "Canyon", prompt: "a deep canyon with a thin river at the bottom, walls in many layers", tags: ["canyon", "river"]},
      {id: "lavender-field", title: "Lavender Rows", prompt: "rows of lavender leading to a small farmhouse", tags: ["lavender", "fields"], category: "Flowers"},
      {id: "glacier", title: "Glacier", prompt: "a glacier tongue meeting a calm fjord with floating ice", tags: ["glacier", "fjord"]},
      {id: "tea-hills", title: "Tea Hills", prompt: "rounded tea hills with neat rows and a winding path", tags: ["tea", "hills"], category: "Nature"},
      {id: "volcano-isle", title: "Quiet Volcano", prompt: "a sleeping volcano island with a thin wisp of steam", tags: ["volcano", "island"]},
      {id: "starry-camp", title: "Starry Camp", prompt: "a single tent glowing under a starry sky between pine layers", tags: ["camping", "stars"]},
      {id: "river-delta", title: "River Delta", prompt: "a river splitting into many streams across a flat delta, seen from above", tags: ["river", "aerial"]},
    ],
    palettes: [
      {id: "sunrise", name: "Sunrise", prompt: "warm sunrise palette of coral, peach and gold", tags: ["warm"]},
      {id: "teal-dusk", name: "Teal Dusk", prompt: "teal, navy and soft orange dusk palette", tags: ["teal"]},
      {id: "forest-green", name: "Evergreen", prompt: "deep greens with a pale cream sky", tags: ["green"]},
      {id: "lilac", name: "Lilac", prompt: "lilac, lavender and soft pink palette", tags: ["purple"]},
      {id: "midnight", name: "Midnight", prompt: "midnight blue and indigo with tiny warm lights", tags: ["blue", "night"]},
      {id: "autumn", name: "Autumn", prompt: "rust, mustard and burnt orange autumn palette", tags: ["autumn"]},
    ],
  },
];
