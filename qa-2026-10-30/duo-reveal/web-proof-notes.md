# Local web proof

Checked 2026-10-30. Web code matches reviewed commit aa7578930.

The empty exported route and two injected geometry fixtures passed browser DOM checks at 390px and 1440px: labels, four loaded preview images, expected Prism and store URLs, responsive grids, and no horizontal overflow. The real empty export has noindex, follow, stays outside sitemap.xml, and has no gallery images. The production manifest remains empty. All three SSR/manifest tests passed again in the parent session.

The four web PNGs use the actual DuoGallery server render and existing exported CSS/header/footer. Direct route screenshots timed out in the preview host, so a standalone HTML renderer captured these instead. The populated fixture replaces only the empty gallery in the page shell. Scripts are removed to prevent production empty-manifest hydration from replacing it. Viewport-height CSS is frozen to 844px for mobile and 1000px for desktop. Existing fonts/CSS are embedded; the reused app icon is downsampled to 96px. No tracked source or CSS changed.

The large fixture disclaimer is deliberately cropped inside the folded image. It is fixture artwork, not clipped site copy. Local fixtures are not approved wallpapers and fail the production publication validator.

These images do not prove hydration, production approval, populated-route metadata/sitemap output, JavaScript behavior, or release readiness. Browser tabs and the local server were closed.
