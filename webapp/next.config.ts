import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Cache Components na Cloudflare Workers (OpenNext) zamrzne požiadavku
  // (Next.js tam nevie spoľahlivo použiť setTimeout), preto vypnuté ako v lehoty.sk.
  cacheComponents: false,
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
