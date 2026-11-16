import Link from "next/link";
import { MealPlanEditor, type EditorPlan } from "@/components/trainer/MealPlanEditor";
import { load, requireTrainer } from "@/lib/trainer";
import { getForTrainer } from "@/server/mealPlans";
import * as trainer from "@/server/trainer";
import { requireUuid } from "@/server/validate";

export default async function MealPlanPage({ params }: PageProps<"/trener/klienti/[id]/jedalnicek/[planId]">) {
  const me = await requireTrainer();
  const { id, planId } = await params;
  const isNew = planId === "novy";

  const { client, plan } = await load(async (db) => {
    const clientId = requireUuid(id);
    const client = (await trainer.clientDetail(db, me.id, clientId)) as unknown as { id: string; name: string; status: string };
    const plan = isNew ? null : await getForTrainer(db, me.id, clientId, requireUuid(planId));
    return { client, plan };
  });

  const initial: EditorPlan = plan
    ? {
        id: plan.id,
        title: plan.title,
        note: plan.note ?? "",
        startsOn: plan.startsOn ?? "",
        targets: plan.targets,
        items: plan.items.map((i) => ({
          id: i.id, day: i.day, meal: i.meal, name: i.name, amount: i.amount ?? "",
          kcal: i.kcal, proteinG: i.proteinG, carbsG: i.carbsG, fatG: i.fatG,
        })),
      }
    : { id: null, title: "", note: "", startsOn: "", targets: { kcal: null, proteinG: null, carbsG: null, fatG: null }, items: [] };

  return (
    <>
      <Link href={`/trener/klienti/${client.id}`} className="text-sm text-muted transition-colors hover:text-ink">
        ← {client.name}
      </Link>
      <h1 className="mt-3 mb-6 font-display text-[clamp(2rem,4vw,3rem)] leading-none font-black">
        {isNew ? "Nový jedálniček" : "Upraviť jedálniček"}
      </h1>
      <MealPlanEditor clientId={client.id} clientName={client.name} canSend={client.status === "linked"} plan={initial} />
    </>
  );
}
