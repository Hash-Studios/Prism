/// A one-tap edit of the wallpaper on screen. It runs the variation path, and [prompt] is the variation request.
///
/// The prompt stays in English for the image model; only the chip label is translated.
enum AiFollowUp {
  watercolour('Repaint it as a soft watercolour painting with visible paper texture'),
  night('Make it a night scene with a dark sky and glowing lights'),
  minimal('Make it more minimal, with fewer elements, more empty space and a simpler palette'),
  warmer('Shift the colours warmer, toward golden and amber tones'),
  depth('Add depth, with a layered foreground and background and a soft atmospheric haze');

  const AiFollowUp(this.prompt);

  final String prompt;
}
