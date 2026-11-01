import {createElement as h} from 'react';
import {duoCopy as copy} from './duo-copy.generated';
import {DUO_REVEAL_SPEC as spec} from './duo_reveal_spec';
import {duoPrismLink, type DuoWall} from './duo-wallpapers';

export function DuoGallery({walls}: {walls: readonly DuoWall[]}) {
  if (!walls.length) return h('div', {className: 'py-14'},
    h('h2', {className: 'text-2xl font-semibold text-white'}, copy.duoWebEmpty),
    h('p', {className: 'mt-3 text-white/75'}, copy.duoWebEmptyBody));
  return h('div', {className: 'space-y-16'}, ...walls.map(wall =>
    h('article', {key: wall.id, className: 'border-t border-white/10 pt-8'},
      h('h2', {className: 'mb-5 text-2xl font-semibold text-white'}, wall.title),
      h('div', {className: 'grid items-end gap-6 sm:grid-cols-[1fr_2fr]'},
        h('figure', null,
          h('div', {style: {aspectRatio: `${spec.outerWidth}/${spec.outerHeight}`, overflow: 'hidden', position: 'relative'},
            className: 'rounded-2xl bg-base-850'},
          h('img', {src: wall.imageUrl, alt: wall.title, width: spec.canvasWidth, height: spec.canvasHeight,
            loading: 'lazy', style: {position: 'absolute', height: '100%', width: `${100 / spec.foldedWidthFraction}%`,
              maxWidth: 'none', right: 0, objectFit: 'cover'}})),
          h('figcaption', {className: 'mt-3 text-sm text-white/75'}, copy.duoWebFolded)),
        h('figure', null,
          h('img', {src: wall.imageUrl, alt: wall.title, width: spec.canvasWidth, height: spec.canvasHeight,
            loading: 'lazy', className: 'h-auto w-full rounded-2xl bg-base-850'}),
          h('figcaption', {className: 'mt-3 text-sm text-white/75'}, copy.duoWebUnfolded))),
      h('a', {href: duoPrismLink(wall), className: 'mt-5 inline-flex min-h-11 items-center font-semibold text-accent underline underline-offset-4 focus-visible:outline-2'},
        copy.duoWebOpenPrism))));
}
