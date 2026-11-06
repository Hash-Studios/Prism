import type { ReactNode } from "react";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";

export function ContentPage({ title, children }: { title: string; children: ReactNode }) {
  return (
    <>
      <Header />
      <main className="min-h-screen bg-neutral-100 px-4 pb-24 pt-32 text-black sm:px-6">
        <article className="mx-auto w-full max-w-3xl">
          <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">{title}</h1>
          <div className="mt-6 space-y-5 leading-relaxed text-neutral-600">{children}</div>
        </article>
      </main>
      <Footer />
    </>
  );
}
