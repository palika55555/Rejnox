import Link from "next/link";
import { AddEventForm, EventActions } from "@/components/trainer/CalendarControls";
import { trainerData } from "@/lib/trainer";
import { localDay, localTime, localToDate, shiftDay, weekStart } from "@/lib/zone";
import { trainerCalendar } from "@/server/calendar";
import { listClients } from "@/server/trainer";

type Booking = {
  id: string;
  startsAt: Date;
  endsAt: Date;
  status: string;
  title: string | null;
  note: string | null;
  slotId: string | null;
  clientName: string;
  requestedByClient: boolean;
};
type Slot = { id: string; startsAt: Date; endsAt: Date; title: string; note: string | null; capacity: number; bookings: Booking[] };

const DAY_LABELS = ["Po", "Ut", "St", "Št", "Pi", "So", "Ne"];
const dayFormat = new Intl.DateTimeFormat("sk-SK", { day: "numeric", month: "numeric", timeZone: "UTC" });
const fmtDay = (day: string) => dayFormat.format(new Date(`${day}T00:00:00Z`));
const span = (a: Date, b: Date) => `${localTime(a)}–${localTime(b)}`;

export default async function CalendarPage({ searchParams }: PageProps<"/trener/kalendar">) {
  const { tyzden } = await searchParams;
  const monday = weekStart(tyzden);
  const range = { start: localToDate(monday, "00:00")!, end: localToDate(shiftDay(monday, 7), "00:00")! };

  const { calendar, roster } = await trainerData(async (db, me) => {
    const calendar = (await trainerCalendar(db, me.id, range)) as unknown as { slots: Slot[]; bookings: Booking[] };
    const roster = (await listClients(db, me.id)) as unknown as { id: string; name: string; status: string }[];
    return { calendar, roster };
  });
  const today = localDay(new Date());
  const days = Array.from({ length: 7 }, (_, i) => shiftDay(monday, i));
  const clients = roster.filter((c) => c.status !== "ended").map(({ id, name }) => ({ id, name }));

  type Event = { at: Date; node: React.ReactNode };
  const byDay = new Map<string, Event[]>(days.map((d) => [d, []]));
  const add = (at: Date, node: React.ReactNode) => byDay.get(localDay(at))?.push({ at, node });

  for (const s of calendar.slots) {
    const taken = s.bookings.filter((b) => b.status !== "cancelled");
    add(
      new Date(s.startsAt),
      <article key={`s${s.id}`} className="rounded-2xl border border-dashed border-brand-violet/50 bg-brand-violet/10 p-3">
        <p className="text-xs font-semibold text-brand-violet">{span(new Date(s.startsAt), new Date(s.endsAt))}</p>
        <p className="font-semibold">{s.title}</p>
        <p className="text-xs text-muted">
          {taken.length}/{s.capacity} obsadené{taken.length ? `: ${taken.map((b) => b.clientName).join(", ")}` : ""}
        </p>
        <EventActions kind="slot" id={s.id} />
      </article>,
    );
  }
  for (const b of calendar.bookings) {
    const isRequested = b.status === "requested";
    add(
      new Date(b.startsAt),
      <article
        key={`b${b.id}`}
        className={`rounded-2xl border p-3 ${isRequested ? "border-flame/60 bg-flame/10" : "border-accent/40 bg-accent/10"}`}
      >
        <p className={`text-xs font-semibold ${isRequested ? "text-flame" : "text-accent"}`}>
          {span(new Date(b.startsAt), new Date(b.endsAt))}
          {isRequested ? " · žiadosť" : ""}
        </p>
        <p className="font-semibold">{b.clientName}</p>
        {b.title && <p className="text-xs text-muted">{b.title}</p>}
        <EventActions kind="booking" id={b.id} isRequested={isRequested} />
      </article>,
    );
  }
  const requests = calendar.bookings.filter((b) => b.status === "requested");

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm font-semibold tracking-[0.2em] text-accent uppercase">Kalendár</p>
          <h1 className="mt-2 font-display text-[clamp(2.2rem,5vw,3.6rem)] leading-none font-black tracking-[-0.02em]">
            {fmtDay(monday)} – {fmtDay(shiftDay(monday, 6))}
          </h1>
        </div>
        <nav className="flex items-center gap-2" aria-label="Týždne">
          <Link href={`/trener/kalendar?tyzden=${shiftDay(monday, -7)}`} className="rounded-full border border-line px-3.5 py-1.5 text-sm font-semibold hover:border-accent">
            ← Predošlý
          </Link>
          <Link href="/trener/kalendar" className="rounded-full border border-line px-3.5 py-1.5 text-sm font-semibold hover:border-accent">
            Tento týždeň
          </Link>
          <Link href={`/trener/kalendar?tyzden=${shiftDay(monday, 7)}`} className="rounded-full border border-line px-3.5 py-1.5 text-sm font-semibold hover:border-accent">
            Ďalší →
          </Link>
        </nav>
      </div>

      {requests.length > 0 && (
        <p className="mt-6 rounded-2xl border border-flame/50 bg-flame/10 px-4 py-3 text-sm">
          <strong className="text-flame">{requests.length} {requests.length === 1 ? "žiadosť čaká" : "žiadosti čakajú"}</strong> na
          potvrdenie – sú vyznačené oranžovo.
        </p>
      )}

      <div className="mt-6 grid gap-6 xl:grid-cols-[1fr_20rem]">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7">
          {days.map((day, i) => {
            const events = (byDay.get(day) ?? []).sort((a, b) => a.at.getTime() - b.at.getTime());
            return (
              <section
                key={day}
                aria-label={`${DAY_LABELS[i]} ${fmtDay(day)}`}
                className={`min-h-40 rounded-3xl border bg-surface p-3 ${day === today ? "border-accent" : "border-line"}`}
              >
                <h2 className="mb-2 flex items-baseline justify-between text-sm font-bold">
                  {DAY_LABELS[i]} <span className={day === today ? "text-accent" : "text-muted"}>{fmtDay(day)}</span>
                </h2>
                <div className="space-y-2">
                  {events.length === 0 ? <p className="text-xs text-muted/70">voľno</p> : events.map((e) => e.node)}
                </div>
              </section>
            );
          })}
        </div>
        <aside className="xl:sticky xl:top-24 xl:self-start">
          <AddEventForm clients={clients} defaultDay={today >= monday && today <= shiftDay(monday, 6) ? today : monday} />
        </aside>
      </div>
    </>
  );
}
