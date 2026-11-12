import type { Metadata } from "next";
import { Suspense } from "react";
import { RedirectIfSignedIn } from "@/components/auth/RedirectIfSignedIn";
import { RegisterForm } from "@/components/auth/RegisterForm";

export const metadata: Metadata = { title: "Registrácia – Rejnox" };

export default function RegisterPage() {
  return (
    <>
      <Suspense fallback={null}>
        <RedirectIfSignedIn />
      </Suspense>
      <h1 className="font-display text-4xl font-black tracking-[-0.03em]">Vytvor si účet</h1>
      <p className="mt-3 mb-8 text-muted">Jeden účet pre web aj mobilnú appku.</p>
      <RegisterForm />
    </>
  );
}
