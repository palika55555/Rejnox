import type { Metadata } from "next";
import { Suspense } from "react";
import { LoginForm } from "@/components/auth/LoginForm";
import { RedirectIfSignedIn } from "@/components/auth/RedirectIfSignedIn";

export const metadata: Metadata = { title: "Prihlásenie – Rejnox" };

export default function LoginPage() {
  return (
    <>
      <Suspense fallback={null}>
        <RedirectIfSignedIn />
      </Suspense>
      <h1 className="font-display text-4xl font-black tracking-[-0.03em]">Vitaj späť</h1>
      <p className="mt-3 mb-8 text-muted">Prihlás sa rovnakým účtom ako v mobilnej appke.</p>
      <LoginForm />
    </>
  );
}
