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
  /**
   * Made for the iOS Lock Screen Depth Effect: prompts use STUDIO_DEPTH_COMPOSITION, and a candidate passes only when
   * the depth check gives tier "auto" or "menu".
   */
  depth?: boolean;
}

export const STUDIO_SUBJECT_COOLDOWN_DAYS = 21;

/** Sent with every prompt of a series without `depth`. Keeps the clock area and the dock calm and keeps text and people out. */
export const STUDIO_COMPOSITION =
  "Vertical phone wallpaper, full bleed. The main subject sits in the middle third of the frame. " +
  "The top quarter and the bottom sixth are calm and low in detail, so a lock screen clock and app icons stay " +
  "readable. Crisp, clean detail, no clutter. The image contains no text, no letters, no numbers, no signature, " +
  "no watermark, no logo and no people.";

/**
 * Sent instead of STUDIO_COMPOSITION with a depth series. The iOS clock spans about 22% to 31% down the screen, and the
 * Depth Effect needs the subject to touch it from below while the clock top stays clear.
 */
export const STUDIO_DEPTH_COMPOSITION =
  "Vertical phone wallpaper, full bleed. The top of the subject (the top of the head, or the peak) sits between 24% " +
  "and 30% down from the top of the frame, centred. The subject fills the frame below that line to the bottom edge. The area above it " +
  "is calm open sky with low detail and nothing else in it. Crisp, clean detail, no clutter. The image contains no " +
  "text, no letters, no numbers, no signature, no watermark and no logo.";

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
      {id: "moth-lamp", title: "Moth Lamp", prompt: "a single moth circling a small glowing lamp in total darkness", tags: ["moth", "lamp"]},
      {id: "cabin-window", title: "Cabin Window", prompt: "one lit window of a small cabin deep in a black forest", tags: ["cabin", "forest"]},
      {id: "candle-flame", title: "Candle Flame", prompt: "a single candle flame standing perfectly still in a black room", tags: ["candle", "flame"]},
      {id: "fog-bridge", title: "Fog Bridge", prompt: "a row of soft lamps fading into fog along an empty bridge at night", tags: ["bridge", "fog"]},
      {id: "night-tree", title: "Night Tree", prompt: "a lone bare tree on a hill under faint moonlight", tags: ["tree", "moonlight"]},
      {id: "harbor-buoy", title: "Harbor Buoy", prompt: "a single plain unmarked buoy light glowing on black still water", tags: ["buoy", "harbor"]},
      {id: "night-greenhouse", title: "Night Greenhouse", prompt: "a small glass greenhouse glowing softly from inside in a dark garden", tags: ["greenhouse", "garden"]},
      {id: "last-embers", title: "Last Embers", prompt: "the last glowing embers of a campfire on black ground, thin smoke rising", tags: ["embers", "campfire"]},
      {id: "tunnel-light", title: "Tunnel Light", prompt: "the round light at the end of a long dark tunnel", tags: ["tunnel", "light"]},
      {id: "still-wheel", title: "Still Wheel", prompt: "a dark ferris wheel with only a few empty cabins lit, their surfaces blank and unmarked, against a black sky", tags: ["ferris wheel", "night"]},
      {id: "porch-light", title: "Porch Light", prompt: "a single porch light over a closed wooden door on a dark street, with a blank door surround and no house-number plaque", tags: ["porch", "door"]},
      {id: "snow-lamp", title: "Snow Lamp", prompt: "snow falling through the cone of light under one street lamp", tags: ["snow", "lamp"]},
      {id: "night-cat", title: "Night Cat", prompt: "the outline of a cat sitting on a rooftop edge, rim lit by moonlight", tags: ["cat", "rooftop"]},
      {id: "moon-boat", title: "Moon Boat", prompt: "an empty rowboat on a black lake under a small bright moon", tags: ["boat", "lake"]},
      {id: "dew-web", title: "Dew Web", prompt: "a spider web with dew drops catching faint light in darkness", tags: ["web", "dew"]},
      {id: "ringed-giant", title: "Ringed Giant", prompt: "a gas giant with wide rings lit from one side, half in shadow", tags: ["planet", "rings"], category: "Space"},
      {id: "earthrise", title: "Earthrise", prompt: "a blue planet rising over a dark grey moon horizon", tags: ["earthrise", "moon"], category: "Space"},
      {id: "asteroid-drift", title: "Asteroid Drift", prompt: "a single cratered asteroid drifting in front of distant stars", tags: ["asteroid", "stars"], category: "Space"},
      {id: "solar-flare", title: "Solar Flare", prompt: "a curved solar flare arching off the edge of a dark sun", tags: ["sun", "flare"], category: "Space"},
      {id: "twin-moons", title: "Twin Moons", prompt: "two small moons rising above a black alien horizon", tags: ["moons", "horizon"], category: "Space"},
      {id: "quiet-station", title: "Quiet Station", prompt: "a small ring shaped space station turning slowly in black space", tags: ["station", "orbit"], category: "Space"},
      {id: "meteor-shower", title: "Meteor Shower", prompt: "thin meteor streaks falling across a black night sky", tags: ["meteors", "sky"], category: "Space"},
      {id: "crater-rim", title: "Crater Rim", prompt: "a close oblique view of a jagged crater rim catching thin light, with the rest of the frame black", tags: ["crater", "moon"], category: "Space"},
      {id: "ice-moon", title: "Ice Moon", prompt: "a cracked icy moon glowing faintly in the dark", tags: ["moon", "ice"], category: "Space"},
      {id: "launch-trail", title: "Launch Trail", prompt: "the bright curved trail of a rocket climbing into a dark sky, seen from far away", tags: ["rocket", "launch"], category: "Space"},
      {id: "spiral-galaxy", title: "Spiral Galaxy", prompt: "a small, faint face-on spiral galaxy with a glowing core and dusty arms, confined to the middle third with most of the frame pure black", tags: ["galaxy", "spiral"], category: "Galaxy"},
      {id: "nebula-pillar", title: "Nebula Pillar", prompt: "a small, narrow, faint pillar of nebula gas lit by young stars, confined to the middle third with most of the frame pure black", tags: ["nebula", "stars"], category: "Galaxy"},
      {id: "star-cluster", title: "Star Cluster", prompt: "a dense ball of stars glowing in deep space", tags: ["cluster", "stars"], category: "Galaxy"},
      {id: "milky-lake", title: "Milky Lake", prompt: "the milky way reflected in a perfectly still black lake", tags: ["milky way", "lake"], category: "Galaxy"},
      {id: "galaxy-pair", title: "Galaxy Pair", prompt: "two small galaxies drifting close together in the dark", tags: ["galaxies", "space"], category: "Galaxy"},
      {id: "ring-nebula", title: "Ring Nebula", prompt: "a small irregular broken oval gas shell around a central star, with an uneven outline", tags: ["nebula", "shell"], category: "Galaxy"},
      {id: "star-trails", title: "Star Trails", prompt: "circular star trails around the pole star above a dark peak", tags: ["star trails", "night"], category: "Galaxy"},
      {id: "cosmic-dust", title: "Cosmic Dust", prompt: "small horizontal wisps of cosmic dust with scattered tiny stars, confined to the middle third with broad pure-black margins", tags: ["dust", "stars"], category: "Galaxy"},
      {id: "event-horizon", title: "Event Horizon", prompt: "a black hole crossed by a tilted thin accretion disc and an asymmetric lensed arc", tags: ["black hole", "space"], category: "Galaxy"},
      {id: "galaxy-tree", title: "Galaxy Tree", prompt: "a lone tree silhouette under a vertical band of the milky way", tags: ["milky way", "tree"], category: "Galaxy"},
      {id: "neon-cube", title: "Neon Cube", prompt: "a wireframe cube drawn in glowing neon lines, floating in darkness", tags: ["cube", "geometry"], category: "Neon"},
      {id: "neon-wave", title: "Neon Wave", prompt: "a single smooth wave traced by glowing neon light", tags: ["wave", "lines"], category: "Neon"},
      {id: "neon-pendulum", title: "Neon Pendulum", prompt: "a single thin glowing pendulum rod and small bob angled across black, with no apparatus labels", tags: ["pendulum", "neon"], category: "Neon"},
      {id: "neon-butterfly", title: "Neon Butterfly", prompt: "a butterfly drawn in thin glowing lines, wings open", tags: ["butterfly", "lines"], category: "Neon"},
      {id: "light-tunnel", title: "Light Tunnel", prompt: "a tunnel of glowing neon rings leading into darkness", tags: ["tunnel", "rings"], category: "Neon"},
      {id: "neon-palm", title: "Neon Palm", prompt: "a single palm tree outlined in neon light against black", tags: ["palm", "neon"], category: "Neon"},
      {id: "neon-peaks", title: "Neon Peaks", prompt: "a mountain range traced by one continuous glowing line", tags: ["mountains", "lines"], category: "Neon"},
      {id: "neon-deer", title: "Neon Deer", prompt: "a deer standing still, outlined in soft glowing light lines", tags: ["deer", "lines"], category: "Neon"},
      {id: "neon-prism", title: "Neon Prism", prompt: "a glowing triangular prism splitting a thin beam of light", tags: ["prism", "light"], category: "Neon"},
      {id: "neon-rain", title: "Neon Rain", prompt: "short vertical glowing droplets beneath an angular eave visible only as a thin outline, against a black background", tags: ["rain", "light"], category: "Neon"},
      {id: "neon-feather", title: "Neon Feather", prompt: "a single feather drawn in glowing filaments, floating", tags: ["feather", "light"], category: "Neon"},
      {id: "neon-hummingbird", title: "Neon Hummingbird", prompt: "a hummingbird drawn in glowing light lines beside one flower", tags: ["hummingbird", "lines"], category: "Neon"},
      {id: "deep-lure", title: "Deep Lure", prompt: "the small glowing lure of an anglerfish in the black deep sea", tags: ["deep sea", "glow"], category: "Ocean"},
      {id: "glow-tide", title: "Glow Tide", prompt: "a wave breaking on a black beach, its edge glowing with plankton", tags: ["plankton", "beach"], category: "Ocean"},
      {id: "glass-squid", title: "Glass Squid", prompt: "a transparent squid glowing softly in black water", tags: ["squid", "deep sea"], category: "Ocean"},
      {id: "night-manta", title: "Night Manta", prompt: "a manta ray gliding above faint light from the sea floor", tags: ["manta", "ocean"], category: "Ocean"},
      {id: "glowing-coral", title: "Glowing Coral", prompt: "a small branch of coral glowing in dark water", tags: ["coral", "glow"], category: "Ocean"},
      {id: "moon-turtle", title: "Moon Turtle", prompt: "a sea turtle swimming through a single shaft of moonlight underwater", tags: ["turtle", "moonlight"], category: "Ocean"},
      {id: "nautilus", title: "Nautilus", prompt: "a nautilus shell drifting in deep black water with faint light on its curves", tags: ["nautilus", "shell"], category: "Ocean"},
      {id: "rising-bubbles", title: "Rising Bubbles", prompt: "a thin column of glowing bubbles rising through black water", tags: ["bubbles", "water"], category: "Ocean"},
      {id: "nested-discs", title: "Nested Discs", prompt: "a small stack of offset solid discs with narrow edge highlights against black", tags: ["discs", "geometry"], category: "Abstract"},
      {id: "liquid-metal", title: "Liquid Metal", prompt: "a single drop of liquid metal frozen mid splash, catching one light", tags: ["metal", "splash"], category: "Abstract"},
      {id: "glass-shards", title: "Glass Shards", prompt: "floating glass shards lit along their edges against black", tags: ["glass", "shards"], category: "Abstract"},
      {id: "dark-silk", title: "Dark Silk", prompt: "a fold of dark silk with one bright highlight along its curve", tags: ["silk", "fabric"], category: "Abstract"},
      {id: "particle-swirl", title: "Particle Swirl", prompt: "a slow swirl of tiny glowing particles in black space", tags: ["particles", "swirl"], category: "Abstract"},
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
      {id: "concrete-block", title: "Concrete Block", prompt: "a brutalist concrete building with deep square windows under a clear sky", tags: ["brutalist", "concrete"]},
      {id: "red-pavilion", title: "Red Pavilion", prompt: "a small red pavilion with a curved roof beside a still pond", tags: ["pavilion", "pond"]},
      {id: "white-lighthouse", title: "White Lighthouse", prompt: "a tall white lighthouse tower against an empty sky", tags: ["lighthouse", "tower"]},
      {id: "salt-house", title: "Salt House", prompt: "a white cubic house on a salt flat with its reflection below", tags: ["house", "reflection"]},
      {id: "amphitheatre", title: "Amphitheatre", prompt: "empty stone amphitheatre steps curving around a small stage", tags: ["stone", "steps"]},
      {id: "folded-roof", title: "Folded Roof", prompt: "a building with a zigzag folded roofline against a clear sky", tags: ["roof", "modern"]},
      {id: "round-tower", title: "Round Tower", prompt: "a round brick tower with a single small window", tags: ["tower", "brick"]},
      {id: "atrium-ramp", title: "Ramp", prompt: "a smooth white ramp spiralling up inside an open atrium", tags: ["ramp", "atrium"]},
      {id: "stone-bridge", title: "Stone Bridge", prompt: "an old stone arched bridge over a calm river", tags: ["bridge", "river"]},
      {id: "hill-windmill", title: "Windmill", prompt: "a single white windmill on a low hill", tags: ["windmill", "hill"]},
      {id: "glass-dome", title: "Glass Dome", prompt: "a geodesic glass greenhouse dome in a quiet garden", tags: ["dome", "greenhouse"]},
      {id: "boathouse", title: "Boathouse", prompt: "a dark timber boathouse over still lake water", tags: ["boathouse", "lake"]},
      {id: "courtyard-well", title: "Courtyard Well", prompt: "a whitewashed courtyard with a round stone well", tags: ["courtyard", "well"]},
      {id: "cable-roof", title: "Cable Roof", prompt: "a minimal tensile canopy held between two slender masts against empty sky", tags: ["canopy", "masts"]},
      {id: "stepped-buttress", title: "Stepped Buttress", prompt: "one stepped stone buttress projecting from a plain exterior wall, seen from the side", tags: ["stone", "buttress"]},
      {id: "grain-silos", title: "Grain Silos", prompt: "a group of round grain silos against a wide sky", tags: ["silos", "rural"]},
      {id: "stilt-house", title: "Stilt House", prompt: "a wooden house on tall stilts above a shallow lagoon", tags: ["stilts", "lagoon"]},
      {id: "cliff-cantilever", title: "Cantilever", prompt: "a long cantilevered house reaching out over a cliff edge", tags: ["cliff", "modern"]},
      {id: "moon-gate", title: "Moon Gate", prompt: "a round moon gate in a white garden wall with a tree beyond it", tags: ["gate", "garden"]},
      {id: "glass-atrium", title: "Atrium", prompt: "a tall atrium with light falling from a glass roof", tags: ["atrium", "light"]},
      {id: "pagoda", title: "Pagoda", prompt: "a slender wooden pagoda rising above soft trees", tags: ["pagoda", "tower"]},
      {id: "floating-stairs", title: "Floating Stairs", prompt: "concrete stairs that seem to float along a bare wall", tags: ["stairs", "concrete"]},
      {id: "hill-observatory", title: "Hill Observatory", prompt: "two small observatory domes on a bare hilltop", tags: ["observatory", "hill"]},
      {id: "tiled-rooftops", title: "Rooftops", prompt: "a few simple tiled roof planes around a single empty courtyard, seen from above with broad blank margins", tags: ["rooftops", "aerial"]},
      {id: "dam-curve", title: "Dam", prompt: "the smooth curve of a concrete dam above a still reservoir", tags: ["dam", "water"]},
      {id: "ice-house", title: "Ice House", prompt: "a small house built of ice blocks glowing softly in snow", tags: ["ice", "house"]},
      {id: "lattice-tower", title: "Lattice Tower", prompt: "a steel lattice tower drawn against a pale sky", tags: ["steel", "tower"]},
      {id: "harbour-crane", title: "Harbour Crane", prompt: "a single tall harbour crane over calm water, with blank unmarked steel surfaces", tags: ["crane", "harbor"]},
      {id: "glass-cube", title: "Glass Cube", prompt: "a glass cube pavilion in a quiet forest clearing", tags: ["glass", "forest"]},
      {id: "bell-tower", title: "Bell Tower", prompt: "a slim white tower above an empty village square, with an open bell arch and visible bell, blank walls and no clock face", tags: ["tower", "village"]},
      {id: "canal-houses", title: "Canal Houses", prompt: "two plain tall narrow house facades lining a wide empty canal", tags: ["canal", "houses"]},
      {id: "earth-wall", title: "Earth Wall", prompt: "a rammed earth wall with soft layered colour stripes", tags: ["earth", "wall"]},
      {id: "edge-pool", title: "Edge Pool", prompt: "an infinity pool edge meeting a flat calm sea", tags: ["pool", "sea"]},
      {id: "forest-lookout", title: "Lookout", prompt: "a wooden lookout tower above a misty forest", tags: ["lookout", "forest"]},
      {id: "round-court", title: "Round Court", prompt: "a circular courtyard open to the sky, seen from inside", tags: ["courtyard", "circle"]},
      {id: "one-chair", title: "One Chair", prompt: "a single chair against a large plain wall", tags: ["chair", "interior"], category: "Minimal"},
      {id: "plaster-niche", title: "Niche", prompt: "a small arched niche in a smooth plaster wall", tags: ["arch", "plaster"], category: "Minimal"},
      {id: "shadow-lines", title: "Shadow Lines", prompt: "parallel shadow lines from a slatted roof falling on a plain floor", tags: ["shadows", "lines"], category: "Minimal"},
      {id: "round-window", title: "Round Window", prompt: "a single round window in a bare wall with sky beyond", tags: ["window", "circle"], category: "Minimal"},
      {id: "corner-light", title: "Corner Light", prompt: "soft light meeting in the corner of two plain walls", tags: ["light", "corner"], category: "Minimal"},
      {id: "sheer-curtain", title: "Curtain", prompt: "a sheer curtain moving in a breeze beside an open window", tags: ["curtain", "window"], category: "Minimal"},
      {id: "step-shadow", title: "Step Shadow", prompt: "three plain steps casting crisp shadows in low sun", tags: ["steps", "shadow"], category: "Minimal"},
      {id: "wall-plant", title: "Wall Plant", prompt: "a single potted plant against a smooth plain wall", tags: ["plant", "wall"], category: "Minimal"},
      {id: "pillar-row", title: "Pillars", prompt: "a row of plain round pillars in soft light", tags: ["pillars", "rhythm"], category: "Minimal"},
      {id: "sky-opening", title: "Opening", prompt: "a square opening in a ceiling that shows only sky", tags: ["skylight", "square"], category: "Minimal"},
      {id: "stone-bench", title: "Bench", prompt: "a long stone bench along an empty wall", tags: ["bench", "stone"], category: "Minimal"},
      {id: "bright-hallway", title: "Hallway", prompt: "an empty hallway ending in a bright doorway", tags: ["hallway", "door"], category: "Minimal"},
      {id: "folded-wall", title: "Folded Wall", prompt: "a white wall folded into soft angled planes", tags: ["wall", "planes"], category: "Minimal"},
      {id: "paper-lamp", title: "Lamp", prompt: "a single paper lamp glowing in an empty room", tags: ["lamp", "interior"], category: "Minimal"},
      {id: "blind-light", title: "Blinds", prompt: "light through half open blinds striping a plain wall", tags: ["blinds", "light"], category: "Minimal"},
      {id: "perforated-wall", title: "Perforated Wall", prompt: "a small grid of circular holes in a thick wall casting separated round patches of light", tags: ["wall", "light"], category: "Minimal"},
      {id: "shelf-vase", title: "Vase", prompt: "a single vase on a narrow shelf in a plain room", tags: ["vase", "shelf"], category: "Minimal"},
      {id: "rail-curve", title: "Railing", prompt: "the curve of a stair railing seen from above", tags: ["railing", "curve"], category: "Minimal"},
      {id: "stone-drain", title: "Stone Drain", prompt: "a narrow carved stone rain channel crossing an otherwise empty paved courtyard, seen from overhead", tags: ["stone", "courtyard"], category: "Minimal"},
      {id: "palm-house", title: "Palm House", prompt: "an old iron and glass palm house in soft light", tags: ["greenhouse", "iron"], category: "Vintage"},
      {id: "deco-facade", title: "Deco Facade", prompt: "an art deco facade with stepped lines and rounded corners", tags: ["art deco", "facade"], category: "Vintage"},
      {id: "old-platform", title: "Old Platform", prompt: "an empty old station platform under a blank unmarked iron canopy, with no clocks, posters or boards", tags: ["station", "iron"], category: "Vintage"},
      {id: "pastel-hotel", title: "Pastel Hotel", prompt: "the pastel upper facade of a shuttered hotel with round balconies, cropped above the ground floor, blank plaster panels with no lettering or emblems", tags: ["pastel", "facade"], category: "Vintage"},
      {id: "keepers-cottage", title: "Keeper's Cottage", prompt: "an old lighthouse keeper's cottage on a rocky point", tags: ["cottage", "coast"], category: "Vintage"},
      {id: "red-barn", title: "Red Barn", prompt: "an old red barn beside a single tree in a wide field", tags: ["barn", "field"], category: "Vintage"},
      {id: "old-stairwell", title: "Old Stairwell", prompt: "an old spiral stairwell with a worn wooden handrail, seen from below", tags: ["stairwell", "wood"], category: "Vintage"},
      {id: "iron-bandstand", title: "Bandstand", prompt: "an empty iron bandstand with sparse slender ironwork in a quiet park", tags: ["bandstand", "park"], category: "Vintage"},
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
      {id: "layered-mesas", title: "Mesa", prompt: "flat topped mesas in layers across a wide desert", tags: ["mesa", "desert"]},
      {id: "hill-cottage", title: "Hill Cottage", prompt: "a small cottage on a green hill with a winding path", tags: ["cottage", "hills"]},
      {id: "basalt-fan", title: "Basalt Fan", prompt: "fan-shaped basalt columns on a sea cliff above distant calm water", tags: ["basalt", "coast"]},
      {id: "salt-flats", title: "Salt Flats", prompt: "white salt flats with distant layered mountains", tags: ["salt", "mountains"]},
      {id: "dune-oasis", title: "Oasis", prompt: "a small oasis with palm trees between layered dunes", tags: ["oasis", "dunes"]},
      {id: "sea-arch", title: "Sea Arch", prompt: "a natural stone arch standing in a calm sea", tags: ["arch", "sea"]},
      {id: "hot-springs", title: "Hot Springs", prompt: "terraced hot spring pools stepping down a hill with soft steam", tags: ["springs", "steam"]},
      {id: "cloud-plateau", title: "Plateau", prompt: "a high plateau with layered clouds below its edge", tags: ["plateau", "clouds"]},
      {id: "arctic-night", title: "Arctic Night", prompt: "a small glowing igloo on layered snow under a green aurora", tags: ["igloo", "aurora"]},
      {id: "red-rocks", title: "Red Rocks", prompt: "layered red rock towers in a quiet desert", tags: ["rocks", "desert"]},
      {id: "moon-peaks", title: "Moon Peaks", prompt: "sharp layered peaks under a big pale moon", tags: ["peaks", "moon"]},
      {id: "steppe-yurt", title: "Steppe", prompt: "a single round yurt on an endless grassy steppe", tags: ["yurt", "steppe"]},
      {id: "lake-isle", title: "Lake Isle", prompt: "an overhead crescent-shaped wooded island enclosing a tiny bay in a still lake, surrounded by wide water", tags: ["island", "bay"]},
      {id: "dry-river", title: "Dry River", prompt: "a dry winding riverbed through layered sandy hills", tags: ["riverbed", "hills"]},
      {id: "hill-village", title: "Hill Village", prompt: "white houses stacked up a steep hillside above the sea", tags: ["village", "hillside"]},
      {id: "cloud-sea", title: "Sea of Clouds", prompt: "mountain tops rising above a sea of clouds", tags: ["clouds", "peaks"]},
      {id: "field-mill", title: "Field Mill", prompt: "an old windmill at the edge of golden layered fields", tags: ["windmill", "fields"]},
      {id: "gorge-bridge", title: "Gorge Bridge", prompt: "a small rope bridge across a deep layered gorge", tags: ["bridge", "gorge"]},
      {id: "bamboo-grove", title: "Bamboo", prompt: "tall layered bamboo stalks with soft light between them", tags: ["bamboo", "forest"], category: "Nature"},
      {id: "fern-floor", title: "Fern Floor", prompt: "a forest floor of layered ferns under tall trunks", tags: ["ferns", "forest"], category: "Nature"},
      {id: "mushroom-glade", title: "Mushrooms", prompt: "a cluster of small mushrooms in a mossy glade", tags: ["mushrooms", "moss"], category: "Nature"},
      {id: "birch-wood", title: "Birch Wood", prompt: "white birch trunks in rows with golden leaves", tags: ["birch", "autumn"], category: "Nature"},
      {id: "snow-fox", title: "Snow Fox", prompt: "a small fox sitting in a snowy pine forest", tags: ["fox", "snow"], category: "Nature"},
      {id: "meadow-deer", title: "Meadow Deer", prompt: "a deer standing in a misty meadow at dawn", tags: ["deer", "meadow"], category: "Nature"},
      {id: "moss-stream", title: "Moss Stream", prompt: "a small stream winding over mossy stones", tags: ["stream", "moss"], category: "Nature"},
      {id: "rain-forest", title: "Rain Forest", prompt: "layered jungle leaves with a thin waterfall behind", tags: ["jungle", "leaves"], category: "Nature"},
      {id: "great-oak", title: "Great Oak", prompt: "a huge old oak tree alone in a field", tags: ["oak", "tree"], category: "Nature"},
      {id: "forest-owl", title: "Owl", prompt: "a small owl on a branch in a quiet night forest", tags: ["owl", "forest"], category: "Nature"},
      {id: "frozen-lake", title: "Frozen Lake", prompt: "a frozen lake with snowy pines around its edge", tags: ["ice", "lake"], category: "Nature"},
      {id: "maple-pond", title: "Maple", prompt: "red maple leaves in layers falling over a pond", tags: ["maple", "leaves"], category: "Nature"},
      {id: "cactus-garden", title: "Cactus", prompt: "tall cacti and round succulents in warm desert light", tags: ["cactus", "desert"], category: "Nature"},
      {id: "mountain-goat", title: "Mountain Goat", prompt: "a mountain goat on a ledge above layered peaks", tags: ["goat", "mountains"], category: "Nature"},
      {id: "rain-woods", title: "Rain Woods", prompt: "soft rain falling through layered forest trees", tags: ["rain", "forest"], category: "Nature"},
      {id: "willow-pond", title: "Willow", prompt: "a weeping willow leaning over a still pond", tags: ["willow", "pond"], category: "Nature"},
      {id: "redwoods", title: "Redwoods", prompt: "giant redwood trunks rising into the mist", tags: ["redwood", "mist"], category: "Nature"},
      {id: "leaf-hedgehog", title: "Hedgehog", prompt: "a small hedgehog low beside a pile of autumn leaves in a wide woodland clearing, with the landscape as the focus", tags: ["hedgehog", "leaves"], category: "Nature"},
      {id: "mangroves", title: "Mangroves", prompt: "mangrove roots in calm shallow water", tags: ["mangrove", "roots"], category: "Nature"},
      {id: "aspen-hill", title: "Aspens", prompt: "a broad overhead hillside of golden aspen canopy clusters and few exposed trunks", tags: ["aspen", "autumn"], category: "Nature"},
      {id: "bee-meadow", title: "Bee Meadow", prompt: "a few bees over a meadow of small wildflowers", tags: ["bees", "meadow"], category: "Nature"},
      {id: "whale-tail", title: "Whale Tail", prompt: "a whale tail rising from calm layered waves", tags: ["whale", "waves"], category: "Ocean"},
      {id: "reef-turtle", title: "Sea Turtle", prompt: "a sea turtle gliding over a layered reef", tags: ["turtle", "reef"], category: "Ocean"},
      {id: "kelp-forest", title: "Kelp Forest", prompt: "tall kelp swaying in sunbeams underwater", tags: ["kelp", "underwater"], category: "Ocean"},
      {id: "tide-pools", title: "Tide Pools", prompt: "small tide pools with shells and starfish among rocks", tags: ["tide pool", "shells"], category: "Ocean"},
      {id: "lone-sailboat", title: "Sailboat", prompt: "a small sailboat on wide layered waves", tags: ["sailboat", "waves"], category: "Ocean"},
      {id: "dolphin-leap", title: "Dolphins", prompt: "two dolphins leaping over gentle waves", tags: ["dolphins", "waves"], category: "Ocean"},
      {id: "hidden-cove", title: "Hidden Cove", prompt: "a quiet cove with a curved sandy beach and cliffs", tags: ["cove", "beach"], category: "Ocean"},
      {id: "iceberg", title: "Iceberg", prompt: "an iceberg floating with its larger part visible underwater", tags: ["iceberg", "sea"], category: "Ocean"},
      {id: "coral-octopus", title: "Octopus", prompt: "a small octopus resting among corals", tags: ["octopus", "coral"], category: "Ocean"},
      {id: "long-pier", title: "Long Pier", prompt: "a long wooden pier stretching into a calm sea", tags: ["pier", "sea"], category: "Ocean"},
      {id: "sunflower-field", title: "Sunflowers", prompt: "a field of sunflowers in layers under a soft sky", tags: ["sunflowers", "field"], category: "Flowers"},
      {id: "lotus-pond", title: "Lotus Pond", prompt: "pink lotus flowers on a calm pond with round leaves", tags: ["lotus", "pond"], category: "Flowers"},
      {id: "alpine-blooms", title: "Alpine Blooms", prompt: "small flowering cushions in cracks along a stepped rocky mountain ledge, in a wide landscape", tags: ["alpine", "flowers"], category: "Flowers"},
      {id: "poppy-hill", title: "Poppies", prompt: "red poppies across a gentle hill", tags: ["poppies", "hill"], category: "Flowers"},
      {id: "wisteria-bridge", title: "Wisteria", prompt: "hanging wisteria over a small wooden bridge", tags: ["wisteria", "bridge"], category: "Flowers"},
      {id: "rose-arch", title: "Rose Arch", prompt: "a garden arch covered in climbing roses", tags: ["roses", "garden"], category: "Flowers"},
      {id: "daisy-meadow", title: "Daisies", prompt: "a meadow of daisies with a single tree", tags: ["daisies", "meadow"], category: "Flowers"},
      {id: "rain-hydrangea", title: "Hydrangea", prompt: "a hydrangea bush beside a winding garden bank with distant hills in soft rain", tags: ["hydrangea", "rain"], category: "Flowers"},
      {id: "wildflower-path", title: "Wild Path", prompt: "a narrow path through tall wildflowers", tags: ["wildflowers", "path"], category: "Flowers"},
      {id: "magnolia-branch", title: "Magnolia", prompt: "a foreground magnolia branch in full bloom framing a distant layered valley", tags: ["magnolia", "valley"], category: "Flowers"},
      {id: "cliff-aloes", title: "Cliff Aloes", prompt: "flowering aloe spikes along a rocky coastal slope, in a wide landscape", tags: ["aloe", "coast"], category: "Flowers"},
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
  {
    id: "depth-effect",
    name: "Depth Effect",
    category: "AI Art",
    tags: ["depth effect", "lock screen"],
    depth: true,
    style:
      "Cinematic photograph look. One large subject with a crisp, clean outline stands out against a wide open sky, " +
      "soft natural light, smooth sky gradient, calm and bold.",
    subjects: [
      {id: "sky-astronaut", title: "Astronaut", prompt: "an astronaut in a plain white suit with no patches or flags, seen from the chest up, helmet off, looking slightly to the side", tags: ["astronaut", "portrait"]},
      {id: "sky-hiker", title: "Summit Hiker", prompt: "a hiker in a plain hooded jacket, seen from the chest up, looking out over the view", tags: ["hiker", "portrait"]},
      {id: "sky-cat", title: "Sky Cat", prompt: "a fluffy cat seen from the chest up, sitting tall with its ears up, looking ahead", tags: ["cat", "pet"], category: "Nature"},
      {id: "sky-dog", title: "Good Dog", prompt: "a golden retriever seen from the chest up, ears soft, looking ahead", tags: ["dog", "pet"], category: "Nature"},
      {id: "sky-peak", title: "Lone Peak", prompt: "a single sharp snow-capped mountain peak rising from the bottom of the frame", tags: ["mountain", "peak"], category: "Landscape"},
      {id: "sky-tower", title: "Sky Tower", prompt: "a slender plain stone tower rising from the bottom of the frame, its rounded top against the sky", tags: ["tower", "sky"], category: "Architecture"},
    ],
    palettes: [
      {id: "golden-hour", name: "Golden Hour", prompt: "warm golden hour light under a clear amber sky", tags: ["warm"]},
      {id: "clear-blue", name: "Clear Blue", prompt: "bright daylight under a deep clear blue sky", tags: ["blue"]},
      {id: "pastel-dawn", name: "Pastel Dawn", prompt: "soft dawn light under a pale peach and lilac sky", tags: ["pastel"]},
      {id: "violet-dusk", name: "Violet Dusk", prompt: "dusk light under a smooth violet and rose sky", tags: ["purple"]},
      {id: "silver-haze", name: "Silver Haze", prompt: "soft diffuse light under a pale silver haze sky", tags: ["grey"]},
      {id: "teal-evening", name: "Teal Evening", prompt: "cool evening light under a smooth teal sky", tags: ["teal"]},
    ],
  },
];
