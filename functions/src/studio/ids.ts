/** A random number in [0, 1), like Math.random. Tests inject a seeded one. */
export type Rng = () => number;

/** Same format as the app's randomUploadId(10): ten capital letters, one of them replaced by a digit. */
export function randomWallId(rng: Rng = Math.random): string {
  const length = 10;
  const digitAt = Math.floor(rng() * length);
  let id = "";
  for (let i = 0; i < length; i++) {
    id += i === digitAt ? String.fromCharCode(0x30 + Math.floor(rng() * 10)) :
      String.fromCharCode(0x41 + Math.floor(rng() * 26));
  }
  return id;
}

/** `${runId}-${index}` with only [A-Za-z0-9_-], 8 to 64 characters: the id the worker and the asset keys accept. */
export function studioCandidateId(runId: string, index: number): string {
  const id = `${runId}-${index}`.replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 64);
  if (id.length < 8) throw new Error(`studio: candidate id ${id} is shorter than 8 characters.`);
  return id;
}
