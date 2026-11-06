import type { Metadata } from "next";
import { ContentPage } from "@/components/content-page";
import { APP_NAME, SITE_URL } from "@/lib/site-config";

const title = `About ${APP_NAME}`;
const description = "Learn about Prism Wallpapers, an open-source wallpaper app for Android and iOS by Hash Studios.";

export const metadata: Metadata = { title, description, alternates: { canonical: "/about", types: { "text/markdown": "/about.md" } }, openGraph: { url: `${SITE_URL}/about`, title, description } };

export default function AboutPage() {
  return <ContentPage title="About Prism Wallpapers">
    <p>Prism is a wallpaper discovery and personalization app built by Hash Studios for people who care about the look and feel of their screens. The app is available for Android and iOS, with an open-source codebase and a focus on making high-quality artwork easier to discover. Browse individual images or explore curated collections by visual style, mood, and subject.</p>
    <h2 className="pt-4 text-2xl font-semibold text-black">A calmer way to find a background</h2>
    <p>Finding a wallpaper should feel inspiring, not like sorting through an unfiltered archive. Prism brings together clear previews, categories, popular picks, and collections so you can move from an idea to a finished home screen. Discover high-resolution images, dark AMOLED-friendly artwork, minimalist designs, landscapes, and more. Save wallpapers you like and return to them when you are ready to personalize your device.</p>
    <p>Hash Studios continues to improve Prism through app updates and community feedback. The project welcomes developers who want to understand the product, build integrations, or contribute through the public repository. Visit the <a className="text-accent underline" href="/developers">developer resources</a>, explore the <a className="text-accent underline" href="/docs">API documentation</a>, or contact the team with questions.</p>
  </ContentPage>;
}
