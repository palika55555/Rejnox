"use server";

import { refresh } from "next/cache";
import { localToDate } from "@/lib/zone";
import { currentUser } from "@/lib/session";
import * as calendar from "@/server/calendar";
import { withDb, type Db } from "@/server/db";
import { HttpError } from "@/server/errors";
import { dbRateLimiter, limits } from "@/server/rateLimit";
import { requireUuid, type Body } from "@/server/validate";

export type CalendarResult = { ok: true } | { ok: false; message: string };

/** Zápis do kalendára: tréner s nevyčerpaným limitom. */
async function write(work: (db: Db, me: string) => Promise<unknown>): Promise<CalendarResult> {
  try {
    const user = await currentUser();
    if (!user || user.role !== "trainer") throw new HttpError(403, "trainers_only", "Táto časť je len pre trénerov.");
    await withDb(async (db) => {
      if (!(await dbRateLimiter(db).tryAcquire(limits.calendarWrite, user.id))) {
        throw new HttpError(429, "too_many_requests", "Priveľa zmien naraz. Skús to o chvíľu.");
      }
      await work(db, user.id);
    });
  } catch (error) {
    if (error instanceof HttpError) return { ok: false, message: error.message };
    throw error;
  }
  refresh();
  return { ok: true };
}

const text = (form: FormData, name: string) => {
  const value = form.get(name);
  return typeof value === "string" ? value.trim() : "";
};

/** Začiatok a koniec z polí deň + od + do (bratislavský čas) ako ISO pre kontrolu v calendar.ts. */
function times(form: FormData): Body {
  const day = text(form, "day");
  const start = localToDate(day, text(form, "from"));
  const end = localToDate(day, text(form, "to"));
  if (!start || !end) throw new HttpError(400, "invalid_time", "Zadaj deň a čas od–do.");
  return { startsAt: start.toISOString(), endsAt: end.toISOString() };
}

export async function addSlotAction(form: FormData): Promise<CalendarResult> {
  return write((db, me) => {
    const capacity = Number(text(form, "capacity") || "1");
    const input = calendar.parseSlot({
      ...times(form),
      capacity,
      title: text(form, "title") || "Voľný termín",
      note: text(form, "note") || null,
    });
    return calendar.addSlot(db, me, input);
  });
}

export async function addBookingAction(form: FormData): Promise<CalendarResult> {
  return write((db, me) => {
    const input = calendar.parseTrainerBooking({
      ...times(form),
      clientId: text(form, "clientId"),
      title: text(form, "title") || null,
      note: text(form, "note") || null,
    });
    return calendar.addTrainerBooking(db, me, input);
  });
}

export async function confirmBookingAction(bookingId: string): Promise<CalendarResult> {
  return write((db, me) => calendar.confirmBooking(db, me, requireUuid(bookingId)));
}

export async function cancelBookingAction(bookingId: string): Promise<CalendarResult> {
  return write((db, me) => calendar.cancelBooking(db, me, requireUuid(bookingId)));
}

export async function deleteSlotAction(slotId: string): Promise<CalendarResult> {
  return write((db, me) => calendar.deleteSlot(db, me, requireUuid(slotId)));
}
