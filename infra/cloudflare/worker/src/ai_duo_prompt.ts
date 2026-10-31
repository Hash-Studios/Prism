import {DUO_REVEAL_SPEC as spec, hasBannedDuoPhrase} from './duo_reveal_spec';

export interface DuoPromptFields {
  format: 'duo-reveal';
  foldedPrompt: string;
  revealedPrompt: string;
}

export function parseDuoPrompt(body: Record<string, unknown>): DuoPromptFields | null {
  if (body.format !== 'duo-reveal') return null;
  const field = (value: unknown): string | null => {
    if (typeof value !== 'string') return null;
    const text = value.trim();
    return text.length >= 1 && text.length <= 160 && !hasBannedDuoPhrase(text) && !/[<>]/.test(text) ? text : null;
  };
  const foldedPrompt = field(body.foldedPrompt);
  const revealedPrompt = field(body.revealedPrompt);
  return foldedPrompt && revealedPrompt ? {format: 'duo-reveal', foldedPrompt, revealedPrompt} : null;
}

export function composeDuoPrompt(fields: DuoPromptFields): string {
  return `One continuous ${spec.canvasWidth}x${spec.canvasHeight} landscape wallpaper. ` +
    `Rightmost ${spec.canvasHeight * spec.outerWidth / spec.outerHeight} pixels show: ${fields.foldedPrompt}. ` +
    `Only the left area reveals: ${fields.revealedPrompt}. Connect both into one coherent scene, not separate panels. ` +
    'Keep the top quarter quiet and low detail. Invent original creatures and objects. No text, logos or watermarks.';
}

export function imageDimensions(bytes: Uint8Array): {width: number; height: number} | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  if (bytes.length >= 24 && view.getUint32(0) === 0x89504e47 && view.getUint32(4) === 0x0d0a1a0a) {
    return {width: view.getUint32(16), height: view.getUint32(20)};
  }
  if (bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset + 9 < bytes.length) {
      if (bytes[offset] !== 0xff) return null;
      const marker = bytes[offset + 1];
      if (marker === 0xda || marker === 0xd9) break;
      const length = view.getUint16(offset + 2);
      if (length < 2 || offset + 2 + length > bytes.length) return null;
      if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
        return {width: view.getUint16(offset + 7), height: view.getUint16(offset + 5)};
      }
      offset += length + 2;
    }
  }
  if (bytes.length >= 30 && view.getUint32(0) === 0x52494646 && view.getUint32(8) === 0x57454250 &&
    view.getUint32(12) === 0x56503858) {
    const uint24 = (at: number) => bytes[at] | bytes[at + 1] << 8 | bytes[at + 2] << 16;
    return {width: uint24(24) + 1, height: uint24(27) + 1};
  }
  if (bytes.length >= 30 && view.getUint32(0) === 0x52494646 && view.getUint32(8) === 0x57454250 &&
    view.getUint32(12) === 0x56503820 && bytes[23] === 0x9d && bytes[24] === 1 && bytes[25] === 0x2a) {
    return {width: view.getUint16(26, true) & 0x3fff, height: view.getUint16(28, true) & 0x3fff};
  }
  if (bytes.length >= 25 && view.getUint32(0) === 0x52494646 && view.getUint32(8) === 0x57454250 &&
    view.getUint32(12) === 0x5650384c && bytes[20] === 0x2f) {
    return {width: 1 + bytes[21] + ((bytes[22] & 0x3f) << 8),
      height: 1 + (bytes[22] >> 6) + (bytes[23] << 2) + ((bytes[24] & 0xf) << 10)};
  }
  return null;
}
