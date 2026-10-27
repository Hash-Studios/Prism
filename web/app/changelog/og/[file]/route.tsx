import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ImageResponse } from "next/og";
import { readChangelog } from "@/lib/changelog";

export const dynamic = "force-static";
export const dynamicParams = false;

export function generateStaticParams() {
  return readChangelog().map((r) => ({ file: `${r.slug}.png` }));
}

const DOT_COLORS = ["#B65CF0", "#F77E7E", "#4FE3EE"];

export async function GET(_request: Request, { params }: { params: Promise<{ file: string }> }) {
  const { file } = await params;
  const release = readChangelog().find((r) => `${r.slug}.png` === file);
  if (!release) {
    return new Response("Not found", { status: 404 });
  }

  const fontDir = join(process.cwd(), "..", "assets", "fonts");
  const [regular, bold, extrabold, logo] = await Promise.all([
    readFile(join(fontDir, "ProximaNova-Regular.otf")),
    readFile(join(fontDir, "Proxima Nova Bold.otf")),
    readFile(join(fontDir, "Proxima Nova Extrabold.otf")),
    readFile(join(process.cwd(), "public", "assets", "prism-logo.png")),
  ]);
  const logoSrc = `data:image/png;base64,${logo.toString("base64")}`;

  const shown = release.bullets.slice(0, 3);
  const extra = release.bullets.length - shown.length;

  return new ImageResponse(
    (
      <div
        style={{
          width: 1200,
          height: 630,
          display: "flex",
          flexDirection: "column",
          position: "relative",
          background: "#0b0b0e",
          color: "#fff",
          fontFamily: "PN",
          padding: "56px 64px",
          backgroundImage:
            "radial-gradient(circle at 88% 18%, rgba(182,92,240,0.35), transparent 45%), radial-gradient(circle at 78% 92%, rgba(79,227,238,0.22), transparent 42%)",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 16, fontSize: 34 }}>
          <img src={logoSrc} width={52} height={52} />
          <span style={{ fontWeight: 700 }}>Prism</span>
          <span style={{ fontWeight: 400, color: "rgba(255,255,255,0.62)" }}>· Changelog</span>
        </div>
        <div
          style={{
            marginTop: 44,
            fontSize: 96,
            fontWeight: 800,
            letterSpacing: -2,
            lineHeight: 1,
          }}
        >
          {release.version}
        </div>
        <div style={{ display: "flex", flexDirection: "column", marginTop: 36, gap: 18 }}>
          {shown.map((bullet, i) => (
            <div
              key={i}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 18,
                fontSize: 32,
                fontWeight: 400,
                color: "rgba(255,255,255,0.86)",
              }}
            >
              <div
                style={{
                  width: 12,
                  height: 12,
                  borderRadius: 6,
                  flexShrink: 0,
                  background: DOT_COLORS[i],
                }}
              />
              <div
                style={{
                  maxWidth: 1000,
                  overflow: "hidden",
                  whiteSpace: "nowrap",
                  textOverflow: "ellipsis",
                }}
              >
                {bullet}
              </div>
            </div>
          ))}
          {extra > 0 ? (
            <div
              style={{
                marginLeft: 30,
                fontSize: 26,
                color: "rgba(255,255,255,0.62)",
              }}
            >
              {`+ ${extra} more`}
            </div>
          ) : null}
        </div>
        <div
          style={{
            position: "absolute",
            left: 64,
            bottom: 44,
            fontSize: 26,
            color: "rgba(255,255,255,0.62)",
          }}
        >
          prismwalls.com/changelog
        </div>
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            bottom: 0,
            height: 10,
            backgroundImage:
              "linear-gradient(90deg, #B65CF0, #E45BD6, #F77E7E, #F9A24E, #EDE84E, #7CF0C0, #4FE3EE, #9FA6F5)",
          }}
        />
      </div>
    ),
    {
      width: 1200,
      height: 630,
      fonts: [
        { name: "PN", data: regular, weight: 400, style: "normal" },
        { name: "PN", data: bold, weight: 700, style: "normal" },
        { name: "PN", data: extrabold, weight: 800, style: "normal" },
      ],
    },
  );
}
