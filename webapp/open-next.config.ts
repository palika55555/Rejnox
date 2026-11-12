import { defineCloudflareConfig } from "@opennextjs/cloudflare";

// `npm run build` spúšťa OpenNext, ten si Next.js zostaví týmto príkazom (inak by sa volal sám seba).
const config = { ...defineCloudflareConfig(), buildCommand: "npx next build" };

export default config;
