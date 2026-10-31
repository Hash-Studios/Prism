import approved from './duo-approved.json' with {type: 'json'};
import {DUO_REVEAL_SPEC as spec} from './duo_reveal_spec';

export interface DuoWall {
  id: string;
  title: string;
  imageUrl: string;
  width: number;
  height: number;
  duoPresetId: string;
  review: true;
}

export function approvedDuoWalls(input: unknown): DuoWall[] {
  if (!Array.isArray(input)) throw new Error('Duo manifest must be an array');
  const ids = new Set<string>();
  return input.map((wall: DuoWall) => {
    if (!wall || typeof wall.id !== 'string' || !/^[A-Za-z0-9_-]+$/.test(wall.id) || ids.has(wall.id) ||
      typeof wall.title !== 'string' || !wall.title.trim() || wall.review !== true ||
      wall.duoPresetId !== spec.presetId || wall.width !== spec.canvasWidth || wall.height !== spec.canvasHeight ||
      typeof wall.imageUrl !== 'string' || !/^https:\/\/prismwalls\.com\/api\/ai\/assets\/ai\/studio\/[A-Za-z0-9_-]+\.jpg$/.test(wall.imageUrl)) {
      throw new Error('Duo manifest requires approved canonical Studio originals');
    }
    ids.add(wall.id);
    return wall;
  });
}

export const duoWalls = approvedDuoWalls(approved);
export const duoRoute = '/iphone-duo-wallpapers';
export const duoIsIndexable = (walls: readonly DuoWall[]) => walls.length > 0;
export const duoPrismLink = (wall: DuoWall) => `https://prismwalls.com/share?id=${encodeURIComponent(wall.id)}&source=prism`;
