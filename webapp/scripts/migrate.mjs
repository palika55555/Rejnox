// Migrácie pri builde na Cloudflare (Workers Builds nastaví WORKERS_CI=1).
// Lokálne sa pri `npm run build` nespúšťajú, aby build omylom nezmenil
// produkčnú databázu. Nasadenie z počítača (`npm run deploy`) ich spustí
// samo cez `npm run db:deploy`.
// Adresu databázy nikdy nevypisuj do logu, je v nej heslo.
import { execSync } from "node:child_process";

const onCloudflare = process.env.WORKERS_CI === "1" || process.env.RUN_MIGRATIONS === "1";

if (!onCloudflare) {
  console.log("Migrácie: lokálny build, preskakujem (spusti `npm run db:deploy`).");
  process.exit(0);
}

if (!process.env.MIGRATION_DATABASE_URL) {
  console.error(
    "Migrácie: chýba MIGRATION_DATABASE_URL (Cloudflare → projekt → Settings → Build → Variables and secrets).",
  );
  process.exit(1);
}

execSync("npx prisma migrate deploy", { stdio: "inherit" });
