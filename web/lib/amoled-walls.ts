export type StudioWall = {
  id: string;
  title: string;
  description: string;
};

export const ORIGINAL_SIZE = { width: 1440, height: 3200 };
export const PREVIEW_SIZE = { width: 1152, height: 2560 };
export const STUDIO_CREDIT = { name: "Prism Studio", href: "/creator/PrismStudio" };

export function previewPath(id: string): string {
  return `/api/catalog/preview/${id}.jpg`;
}

export const amoledWalls: StudioWall[] = [
  {
    id: "OUUKGMD2GF",
    title: "Night Tree · Silver",
    description:
      "A bare tree on a rocky hilltop under a full moon. Thin cloud catches the moonlight, and the sky above and the ground below fall away to black.",
  },
  {
    id: "DPDKYZKHQ4",
    title: "Harbor Buoy · Silver",
    description:
      "A lit navigation buoy on still water. Its lamp makes a broken line of light down the frame, and the rest is black water and sky.",
  },
  {
    id: "PJ5XLPYRKQ",
    title: "Aurora Ridge · Silver",
    description:
      "A pale aurora curves over a row of snow-capped peaks, with a few stars. Below the ridge, the frame fades to black.",
  },
  {
    id: "ZLOHKQ3MLH",
    title: "Deep Whale · Violet",
    description:
      "A humpback whale drawn in glowing violet and magenta light, with small specks around it, rising across a black field.",
  },
  {
    id: "PGEULKSP1E",
    title: "Porch Light · Ice",
    description:
      "A dark panelled front door under one porch lamp, with shrubs on each side. Cold blue light falls on wet steps and the path in front.",
  },
  {
    id: "KHQ6OSMHDS",
    title: "Snow Lamp · Silver",
    description:
      "An old street lamp throws a cone of light through falling snow onto snowy ground. Around the light, the night stays black.",
  },
];
