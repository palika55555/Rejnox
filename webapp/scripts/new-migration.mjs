// Nová prázdna migrácia: `npm run db:new -- nazov_zmeny`.
// Vytvorí prisma/migrations/<čas>_<názov>/migration.sql, SQL dopíšeš ručne.
// Raz nahratú migráciu už nemeň, vždy pridaj novú.
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const name = (process.argv[2] ?? "").toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "");
if (!name) {
  console.error("Použitie: npm run db:new -- nazov_zmeny");
  process.exit(1);
}

const stamp = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);
const dir = join("prisma", "migrations", `${stamp}_${name}`);
mkdirSync(dir, { recursive: true });
writeFileSync(
  join(dir, "migration.sql"),
  `-- Rejnox: ${name.replaceAll("_", " ")}.\n-- Nové tabuľky: GRANT pre rejnox_app a ENABLE ROW LEVEL SECURITY s pravidlami.\n\n`,
);
console.log(`Vytvorená ${join(dir, "migration.sql")}`);
