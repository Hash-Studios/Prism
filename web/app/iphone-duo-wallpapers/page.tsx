import type {Metadata} from 'next';
import {Header} from '@/components/sections/header';
import {Footer} from '@/components/sections/footer';
import {Button} from '@/components/ui/button';
import {APP_STORE_URL, PLAY_STORE_URL, SITE_URL} from '@/lib/site-config';
import {duoCopy as copy} from '@/lib/duo-copy.generated';
import {DuoGallery} from '@/lib/duo-gallery';
import {duoIsIndexable, duoRoute, duoWalls} from '@/lib/duo-wallpapers';

export const metadata: Metadata = {
  title: copy.duoWebTitle,
  description: copy.duoWebDescription,
  alternates: {canonical: `${SITE_URL}${duoRoute}`},
  robots: {index: duoIsIndexable(duoWalls), follow: true},
};

export default function DuoWallpapersPage() {
  return <>
    <Header />
    <main className="min-h-screen bg-base-900">
      <section className="mx-auto w-full max-w-5xl px-4 py-20 sm:px-6 sm:py-24 lg:px-8">
        <h1 className="max-w-3xl text-balance text-4xl font-bold tracking-tight text-white sm:text-5xl">{copy.duoWebHeading}</h1>
        <p className="mt-5 max-w-2xl text-lg leading-relaxed text-white/75">{copy.duoWebIntro}</p>
        <div className="mt-8 flex flex-wrap gap-3">
          <Button href={APP_STORE_URL}>{copy.duoWebAppStore}</Button>
          <Button href={PLAY_STORE_URL} variant="secondary">{copy.duoWebPlayStore}</Button>
        </div>
        <div className="mt-14"><DuoGallery walls={duoWalls} /></div>
        <p className="mt-12 max-w-2xl text-sm leading-relaxed text-white/75">{copy.duoWebPresetNotice}</p>
        <a href="/" className="mt-5 inline-flex min-h-11 items-center text-accent underline underline-offset-4">{copy.duoWebExplore}</a>
      </section>
    </main>
    <Footer />
  </>;
}
