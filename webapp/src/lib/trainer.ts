import "server-only";

import { notFound, redirect } from "next/navigation";
import { userForToken, type AuthUser } from "@/server/auth";
import { withDb, type Db } from "@/server/db";
import { HttpError } from "@/server/errors";
import { currentUser, sessionToken, type User } from "./session";

/** Prihlásený tréner, inak presmerovanie (na prihlásenie alebo do bežného prehľadu). */
export async function requireTrainer(): Promise<User> {
  const user = await currentUser();
  if (!user) redirect("/prihlasenie");
  if (user.role !== "trainer") redirect("/prehlad");
  return user;
}

/**
 * Dáta stránky trénera cez jedno spojenie s databázou: overenie relácie aj
 * dopyty idú za sebou na tom istom spojení (každé nové spojenie stojí desiatky ms).
 * „Nenájdené“ z API zmení na 404 stránku.
 */
export async function trainerData<T>(body: (db: Db, me: AuthUser) => Promise<T>): Promise<T> {
  const token = await sessionToken();
  if (!token) redirect("/prihlasenie");
  let outcome: { kind: "ok"; value: T } | { kind: "signin" } | { kind: "member" };
  try {
    outcome = await withDb(async (db) => {
      const me = await userForToken(db, token);
      if (!me) return { kind: "signin" as const };
      if (me.role !== "trainer") return { kind: "member" as const };
      return { kind: "ok" as const, value: await body(db, me) };
    });
  } catch (error) {
    if (error instanceof HttpError && (error.status === 404 || error.status === 400)) notFound();
    throw error;
  }
  if (outcome.kind === "signin") redirect("/prihlasenie");
  if (outcome.kind === "member") redirect("/prehlad");
  return outcome.value;
}
