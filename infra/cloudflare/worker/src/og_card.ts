// Link preview cards, rendered to a 1200x630 image by Browser Rendering.
// Wallpaper, setup and profile links use the data card. Invite links use the showcase card.
// Both share the brand line, the person chip, the blurred backdrop and the ring-colour bar.

const ASSET_BASE = 'https://raw.githubusercontent.com/Hash-Studios/Prism/master/assets';
const LOGO_URL = `${ASSET_BASE}/images/prism.webp`;
const RING_COLORS = ['#B65CF0', '#E45BD6', '#F77E7E', '#F9A24E', '#EDE84E', '#7CF0C0', '#4FE3EE', '#9FA6F5'];

export type OgIcon = 'eye' | 'heart' | 'download' | 'phone' | 'image' | 'users';

export interface OgStat {
  icon: OgIcon;
  value: string;
  label: string;
}

export interface OgChip {
  photo: string;
  prefix: string;
  name: string;
  detail: string;
}

export type OgCard =
  | { kind: 'wallpaper'; label: string; title: string; image: string; stats: OgStat[]; chip: OgChip | null }
  | { kind: 'profile'; name: string; handle: string; photo: string; stats: OgStat[]; gallery: string[]; more: string }
  | { kind: 'invite'; gallery: string[]; chip: OgChip };

const ICON_PATHS: Record<OgIcon, string> = {
  eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  heart: '<path d="M12 20.5s-7.5-4.6-9.6-9C.9 8 3.1 4.5 6.6 4.5c2.1 0 3.7 1.1 5.4 3.2 1.7-2.1 3.3-3.2 5.4-3.2 3.5 0 5.7 3.5 4.2 7-2.1 4.4-9.6 9-9.6 9z"/>',
  download: '<path d="M12 3.5v11.5M6.5 10l5.5 5.5 5.5-5.5M4 20.5h16"/>',
  phone: '<rect x="6.5" y="2.5" width="11" height="19" rx="2.5"/><path d="M10.5 18.5h3"/>',
  image: '<rect x="3.5" y="3.5" width="17" height="17" rx="3"/><circle cx="9" cy="9" r="1.8"/><path d="M20.5 15.5l-5-5-11 10"/>',
  users: '<circle cx="9" cy="8" r="3.6"/><path d="M2.5 20c.6-3.6 3.3-5.6 6.5-5.6s5.9 2 6.5 5.6"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18.2 14.7c1.8.8 3 2.6 3.3 5.3"/>',
};

const BASE_CSS = `
@font-face { font-family: PN; src: url("${ASSET_BASE}/fonts/ProximaNova-Regular.otf"); font-weight: 400; }
@font-face { font-family: PN; src: url("${ASSET_BASE}/fonts/Proxima%20Nova%20Bold.otf"); font-weight: 700; }
@font-face { font-family: PN; src: url("${ASSET_BASE}/fonts/Proxima%20Nova%20Extrabold.otf"); font-weight: 800; }
* { box-sizing: border-box; }
body { margin: 0; width: 1200px; height: 630px; overflow: hidden; position: relative; background: #0b0b0e; color: #fff;
  font-family: PN, -apple-system, Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased; }
.bg { position: absolute; left: -80px; top: -80px; width: 1360px; height: 790px; object-fit: cover; }
.shade { position: absolute; inset: 0; }
.bar { position: absolute; left: 0; right: 0; bottom: 0; height: 10px; background: linear-gradient(90deg, ${RING_COLORS.join(', ')}); }
.brand { position: absolute; left: 64px; top: 56px; display: flex; align-items: center; gap: 16px; font-size: 34px; font-weight: 700; letter-spacing: -.2px; }
.brand img { width: 52px; height: 52px; }
.brand .ctx { font-weight: 400; color: rgba(255,255,255,.62); }
.chip { position: absolute; left: 64px; bottom: 58px; max-width: 640px; display: flex; align-items: center; gap: 16px; font-size: 28px; line-height: 1.15; }
.chip .who { display: flex; flex-direction: column; min-width: 0; }
.chip .who span { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.chip b { font-weight: 700; }
.chip .sub { color: rgba(255,255,255,.62); font-size: 24px; }
.avatar { border-radius: 50%; object-fit: cover; border: 3px solid rgba(255,255,255,.9); flex: none; }
.chip .avatar { width: 64px; height: 64px; }
.tile { position: absolute; border-radius: 28px; overflow: hidden; background: #16161b; box-shadow: 0 28px 60px rgba(0,0,0,.55); }
.tile img { width: 100%; height: 100%; object-fit: cover; display: block; }
.tile img.logo { object-fit: contain; padding: 25%; }
.tile::after { content: ''; position: absolute; inset: 0; border-radius: inherit; box-shadow: inset 0 0 0 2px rgba(255,255,255,.16); }
.title { position: absolute; left: 64px; top: 146px; width: 700px; font-size: 68px; font-weight: 800; line-height: 1.04; letter-spacing: -1.2px;
  display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; overflow-wrap: anywhere; }
.handle { color: rgba(255,255,255,.62); font-size: 34px; font-weight: 400; letter-spacing: 0; margin-top: 12px; display: block; }
.stats { position: absolute; left: 64px; top: 380px; display: flex; gap: 44px; }
.stat { display: flex; align-items: flex-start; gap: 12px; }
.stat svg { width: 34px; height: 34px; color: rgba(255,255,255,.62); margin-top: 3px; flex: none; }
.stat .num { font-size: 38px; font-weight: 700; line-height: 1; white-space: nowrap; }
.stat .lbl { font-size: 24px; color: rgba(255,255,255,.62); margin-top: 6px; }
.stack { position: absolute; left: 64px; bottom: 58px; display: flex; align-items: center; }
.mini { width: 52px; height: 92px; border-radius: 10px; overflow: hidden; margin-right: -14px; border: 3px solid #0b0b0e; box-shadow: 0 6px 14px rgba(0,0,0,.5); }
.mini img { width: 100%; height: 100%; object-fit: cover; display: block; }
.stack .more { margin-left: 32px; font-size: 26px; color: rgba(255,255,255,.62); }
.big-avatar { position: absolute; right: 72px; top: 64px; width: 248px; height: 248px; }
.data .bg { filter: blur(64px) saturate(1.2) brightness(.3); }
.data .shade { background: linear-gradient(90deg, rgba(11,11,14,.92) 0%, rgba(11,11,14,.78) 55%, rgba(11,11,14,.35) 100%); }
.showcase .bg { filter: blur(64px) saturate(1.25) brightness(.42); }
.showcase .shade { background: linear-gradient(90deg, rgba(0,0,0,.35) 0%, rgba(0,0,0,0) 45%); }
`;

export function renderOgCardHtml(card: OgCard): string {
  if (card.kind === 'wallpaper') {
    return renderWallpaperCard(card);
  }
  if (card.kind === 'profile') {
    return renderProfileCard(card);
  }
  return renderInviteCard(card);
}

/** 999 -> "999", 1234 -> "1.2k", 51000 -> "51k", 2500000 -> "2.5M". */
export function formatCount(value: number): string {
  const units: Array<[number, string]> = [[1e9, 'B'], [1e6, 'M'], [1e3, 'k']];
  for (const [size, suffix] of units) {
    if (value >= size) {
      const scaled = value / size;
      const rounded = scaled >= 10 ? Math.floor(scaled) : Math.floor(scaled * 10) / 10;
      return `${rounded}${suffix}`;
    }
  }
  return String(value);
}

function renderWallpaperCard(card: Extract<OgCard, { kind: 'wallpaper' }>): string {
  const width = 330;
  const height = Math.round(width * 19.5 / 9);
  const tileImage = card.image ? `<img src="${esc(card.image)}" alt="">` : `<img class="logo" src="${esc(LOGO_URL)}" alt="">`;
  return page('data', card.image, `${brand(card.label)}
<div class="title" style="width:640px">${esc(card.title)}</div>
${stats(card.stats)}
<div class="tile" style="right:84px;top:72px;width:${width}px;height:${height}px;transform:rotate(4deg);transform-origin:top left">${tileImage}</div>
${card.chip ? chip(card.chip) : ''}`);
}

function renderProfileCard(card: Extract<OgCard, { kind: 'profile' }>): string {
  const avatar = card.photo
    ? `<img class="avatar big-avatar" src="${esc(card.photo)}" alt="">`
    : `<img class="big-avatar" src="${esc(LOGO_URL)}" alt="">`;
  const handle = card.handle ? `<span class="handle">${esc(card.handle)}</span>` : '';
  const stack = card.gallery.length > 0
    ? `<div class="stack">${card.gallery.map((src) => `<div class="mini"><img src="${esc(src)}" alt=""></div>`).join('')}`
      + `${card.more ? `<span class="more">${esc(card.more)}</span>` : ''}</div>`
    : '';
  return page('data', card.gallery[0] || card.photo, `${brand('Creator')}${avatar}
<div class="title" style="width:${card.photo ? 700 : 760}px">${esc(card.name)}${handle}</div>
${stats(card.stats)}${stack}`);
}

function renderInviteCard(card: Extract<OgCard, { kind: 'invite' }>): string {
  const images = card.gallery.slice(0, 3);
  const height = 480;
  const width = Math.round(height * 9 / 19.5);
  const gap = 22;
  const left = 1200 - 64 - (images.length * width + (images.length - 1) * gap);
  const top = (620 - height) / 2 - 6;
  const tiles = images.map((src, i) =>
    `<div class="tile" style="left:${left + i * (width + gap)}px;top:${top}px;width:${width}px;height:${height}px">`
    + `<img src="${esc(src)}" alt=""></div>`).join('');
  return page('showcase', images[0] ?? '', `${brand('Invite')}${tiles}${chip(card.chip)}`);
}

function page(style: 'data' | 'showcase', backdrop: string, content: string): string {
  const bg = backdrop ? `<img class="bg" src="${esc(backdrop)}" alt="">` : '';
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<style>${BASE_CSS}</style>
</head>
<body class="${style}">
${bg}<div class="shade"></div>
${content}
<div class="bar"></div>
</body>
</html>`;
}

function brand(label: string): string {
  return `<div class="brand"><img src="${esc(LOGO_URL)}" alt=""><span>Prism</span><span class="ctx">· ${esc(label)}</span></div>`;
}

function chip(value: OgChip): string {
  const photo = value.photo ? `<img class="avatar" src="${esc(value.photo)}" alt="">` : '';
  const prefix = value.prefix ? `${esc(value.prefix)} ` : '';
  const detail = value.detail ? `<span class="sub">${esc(value.detail)}</span>` : '';
  return `<div class="chip">${photo}<div class="who"><span>${prefix}<b>${esc(value.name)}</b></span>${detail}</div></div>`;
}

function stats(items: OgStat[]): string {
  if (items.length === 0) {
    return '';
  }
  return `<div class="stats">${items.map((item) => `<div class="stat">${icon(item.icon)}<div>`
    + `<div class="num">${esc(item.value)}</div><div class="lbl">${esc(item.label)}</div></div></div>`).join('')}</div>`;
}

function icon(name: OgIcon): string {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICON_PATHS[name]}</svg>`;
}

function esc(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
