import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Cache Components na Cloudflare Workers (OpenNext) zamrzne požiadavku
  // (Next.js tam nevie spoľahlivo použiť setTimeout), preto vypnuté ako v lehoty.sk.
  cacheComponents: false,
  experimental: {
    // Prehliadač si pamätá navštívené stránky 30 s, takže návrat späť (napr.
    // klient → prehľad) je okamžitý. Každá zmena (server akcia) volá refresh().
    staleTimes: { dynamic: 30, static: 180 },
  },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
