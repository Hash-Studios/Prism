// Most styles read clearly from the name alone. These read as a photo from the name, so they say what the style
// looks like. tool/ai_style_samples.mjs builds the style samples with the same text.
const STYLE_DESCRIPTIONS: ReadonlyMap<string, string> = new Map([
  ['3d render', 'stylized 3D render, smooth matte clay-like materials, soft global illumination, rendered CGI look'],
]);

/** The text added after the user's prompt for [stylePreset]. */
export function stylePromptSuffix(stylePreset: string): string {
  return STYLE_DESCRIPTIONS.get(stylePreset.trim().toLowerCase()) ?? `${stylePreset} style`;
}
