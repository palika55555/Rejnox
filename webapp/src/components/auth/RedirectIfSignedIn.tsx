import { redirect } from "next/navigation";
import { currentUser } from "@/lib/session";

/** Prihláseného návštevníka pošle z prihlásenia či registrácie na prehľad. */
export async function RedirectIfSignedIn() {
  if (await currentUser()) redirect("/prehlad");
  return null;
}
