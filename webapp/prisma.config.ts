// Prisma CLI (migrácie). Adresa databázy sa číta z prostredia, nikdy nie je v kóde:
// - lokálne z webapp/.env (v gite nie je),
// - na Cloudflare z premennej buildu MIGRATION_DATABASE_URL.
// Migrácie bežia ako vlastník schémy (postgres), cez Supabase Session pooler (port 5432).
import "dotenv/config";
import { defineConfig } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: { path: "prisma/migrations" },
  datasource: { url: process.env.MIGRATION_DATABASE_URL ?? "" },
});
