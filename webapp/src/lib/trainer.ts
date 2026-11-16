import "server-only";

import { notFound, redirect } from "next/navigation";
import { withDb, type Db } from "@/server/db";
import { HttpError } from "@/server/errors";
import { currentUser, type User } from "./session";

/** Prihlásený tréner, inak presmerovanie (na prihlásenie alebo do bežného prehľadu). */
export async function requireTrainer(): Promise<User> {
  const user = await currentUser();
  if (!user) redirect("/prihlasenie");
  if (user.role !== "trainer") redirect("/prehlad");
  return user;
}

/** Načíta dáta pre stránku trénera; „nenájdené“ z API zmení na 404 stránku. */
export async function load<T>(body: (db: Db) => Promise<T>): Promise<T> {
  try {
    return await withDb(body);
  } catch (error) {
    if (error instanceof HttpError && (error.status === 404 || error.status === 400)) notFound();
    throw error;
  }
}
