// Styles that read as a photo from the name alone. tool/ai_style_samples.mjs uses this text for the style samples.
const STYLE_DESCRIPTIONS: ReadonlyMap<string, string> = new Map([
  ['3d render', 'stylized 3D render, smooth matte clay-like materials, soft global illumination, rendered CGI look'],
]);

export function stylePromptSuffix(stylePreset: string): string {
  return STYLE_DESCRIPTIONS.get(stylePreset.trim().toLowerCase()) ?? `${stylePreset} style`;
}
