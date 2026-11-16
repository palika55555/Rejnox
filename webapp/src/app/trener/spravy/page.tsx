import { BulkMessageForm } from "@/components/trainer/BulkMessageForm";
import { trainerData } from "@/lib/trainer";
import { listClients } from "@/server/trainer";

export default async function BulkMessagesPage() {
  const clients = (await trainerData((db, me) => listClients(db, me.id))) as unknown as {
    id: string;
    name: string;
    note: string | null;
    status: string;
    hasAccount: boolean;
  }[];
  const active = clients
    .filter((c) => c.status !== "ended")
    .map((c) => ({ id: c.id, name: c.name, note: c.note, isLinked: c.status === "linked" && c.hasAccount }));

  return (
    <>
      <p className="text-sm font-semibold tracking-[0.2em] text-accent uppercase">Správy</p>
      <h1 className="mt-2 font-display text-[clamp(2.2rem,5vw,3.6rem)] leading-none font-black tracking-[-0.02em]">
        Hromadná správa
      </h1>
      <p className="mt-3 mb-8 max-w-xl text-muted">
        Každý klient dostane správu zvlášť do svojho chatu s tebou v appke Rejnox, odpovede uvidíš tam.
      </p>
      {active.length === 0 ? (
        <p className="rounded-3xl border border-dashed border-line p-10 text-center text-muted">Zatiaľ nemáš klientov.</p>
      ) : (
        <BulkMessageForm clients={active} />
      )}
    </>
  );
}
