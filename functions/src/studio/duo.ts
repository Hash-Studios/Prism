import {DUO_REVEAL_SPEC as spec} from "../duo_reveal_spec";
import type {StudioSeries} from "./series";

export const DUO_SERIES_ID = "duo-reveal";
export const DUO_PROVIDER_SIZE = {
  width: Math.ceil(spec.canvasWidth / 32) * 32,
  height: Math.ceil(spec.canvasHeight / 16) * 16,
};

export const DUO_SUBJECT_PAIRS = [
  ["Acorn courier", "a tiny squirrel holding one acorn", "a woodland sorting office inside a hollow tree"],
  ["Otter bath", "an otter floating beside a leaf", "a river spa with pebble pools and reed curtains"],
  ["Fox lantern", "a fox watching a small lantern", "a valley of glowing mushroom houses"],
  ["Turtle orchard", "a turtle beneath a single blossom", "an orchard growing on its enormous shell"],
  ["Owl observatory", "an owl peeking from a round window", "a treetop telescope workshop under the stars"],
  ["Snail express", "a snail beside a tiny parcel", "a miniature railway built around its spiral shell"],
  ["Penguin picnic", "a penguin holding an empty cup", "a floating iceberg picnic with a fish-shaped teapot"],
  ["Whale garden", "a small luminous fish in dark water", "a sleeping whale carrying a coral garden"],
  ["Teacup harbor", "a plain porcelain cup on a table", "tiny sailboats sheltering in the cup saucer"],
  ["Umbrella forest", "a red umbrella resting on moss", "a forest of giant umbrellas after rain"],
  ["Key greenhouse", "an old brass key on a leaf", "a glass greenhouse shaped like its lock"],
  ["Pencil bridge", "a short unmarked pencil on a desk", "a tiny bridge crew building over a paper river"],
  ["Boot meadow", "a worn boot with one daisy", "a miniature meadow spilling from its open laces"],
  ["Bottle tide", "a clear bottle catching blue light", "a whole tidal world continuing outside its glass"],
  ["Clockwork seed", "a glowing seed in a metal cradle", "a mechanical orchard powered by moonlight"],
  ["Lunar laundry", "a small original rover holding a sock", "a laundry line stretched between moon craters"],
  ["Cloud mechanic", "a little original robot with a spanner", "a floating workshop repairing rain clouds"],
  ["Comet kitchen", "a copper kettle releasing a curl of steam", "a kitchen on a comet with drifting herb pots"],
  ["Orbit greenhouse", "a sprout behind a round porthole", "a ring-shaped greenhouse orbiting a violet planet"],
  ["Star ferry", "a paper boat carrying a single light", "a quiet river of stars beneath a cosmic arch"],
  ["Dumpling nap", "a sleepy round dumpling creature", "its cozy bamboo room with a pea-shaped pillow"],
  ["Bread mountain", "a tiny mouse beside a bread crumb", "an enormous loaf mountain with butter ski slopes"],
  ["Sock dragon", "a small original dragon hugging a sock", "a cave full of mismatched socks arranged as treasure"],
  ["Pear parade", "a pear with tiny wooden wheels", "a vegetable parade crossing a kitchen counter"],
] as const;

export function duoComposition(folded: string, revealed: string): string {
  return `One continuous ${spec.canvasWidth}x${spec.canvasHeight} landscape wallpaper. ` +
    `The rightmost ${spec.canvasHeight * spec.outerWidth / spec.outerHeight} pixels show: ${folded}. ` +
    `Only the left area reveals: ${revealed}. Both areas form one coherent scene, not panels or a collage. ` +
    "Keep the top quarter quiet and low detail. No text or logos. Invent every subject; use only original creatures and objects.";
}

export const DUO_SERIES: StudioSeries = {
  id: DUO_SERIES_ID, name: "Duo reveal", category: "AI Art", manualOnly: true, duoReveal: true,
  tags: ["duo", "duo-reveal"],
  style: "Original editorial illustration, tactile detail, clear silhouettes and soft directional light.",
  subjects: DUO_SUBJECT_PAIRS.map(([title, foldedPrompt, revealedPrompt], index) => ({
    id: `duo-original-${index + 1}`, title, prompt: duoComposition(foldedPrompt, revealedPrompt),
    foldedPrompt, revealedPrompt, tags: [],
  })),
  palettes: [{id: "natural", name: "Natural", prompt: "a restrained harmonious palette", tags: []}],
};
