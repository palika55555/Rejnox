import Link from "next/link";
import type { ReactNode } from "react";
import { SiteFooter } from "@/components/landing/SiteFooter";
import { RejnoxMark } from "@/components/landing/RejnoxMark";
import { legalUpdatedAt, operator } from "@/lib/legal";

/** Spoločné rozloženie právnych stránok (zásady, cookies). */
export function LegalPage({ title, intro, children }: { title: string; intro: string; children: ReactNode }) {
  return (
    <>
      <header className="border-b border-line">
        <div className="mx-auto flex h-16 max-w-3xl items-center px-4 sm:px-6">
          <Link href="/" className="flex items-center gap-3" aria-label="Rejnox, späť na úvod">
            <RejnoxMark className="w-8" title="" />
            <span className="font-display text-sm font-bold tracking-[0.32em]">REJNOX</span>
          </Link>
        </div>
      </header>
      <main className="legal mx-auto max-w-3xl px-4 py-14 sm:px-6 lg:py-20">
        <p className="text-sm text-muted">Platné od {legalUpdatedAt}</p>
        <h1 className="mt-2 font-display text-[clamp(2.2rem,6vw,3.5rem)] leading-[1.02] font-black tracking-[-0.03em]">
          {title}
        </h1>
        <p className="mt-5 text-lg leading-relaxed text-muted">{intro}</p>
        <div className="mt-12 space-y-10">{children}</div>
      </main>
      <SiteFooter />
    </>
  );
}

export function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h2 className="font-display text-xl font-extrabold">{title}</h2>
      <div className="mt-3 space-y-3 leading-relaxed text-muted [&_b]:font-semibold [&_b]:text-ink [&_li]:ml-5 [&_li]:list-disc [&_li]:pl-1 [&_ul]:space-y-1.5">
        {children}
      </div>
    </section>
  );
}

/** Hodnota prevádzkovateľa alebo zvýraznené upozornenie, že chýba. */
export function Fill({ value, label }: { value: string | null; label: string }) {
  if (value) return <>{value}</>;
  return <mark className="rounded bg-flame/20 px-1 text-flame">[doplniť: {label}]</mark>;
}

export function OperatorContact() {
  return (
    <>
      <b>
        <Fill value={operator.name} label="meno alebo obchodné meno" />
      </b>
      {operator.ico ? `, IČO ${operator.ico}` : ""}
      {operator.address ? `, ${operator.address}` : ""}
      {!operator.ico ? " (fyzická osoba)" : ""}. Kontakt pre otázky k osobným údajom a uplatnenie
      tvojich práv:{" "}
      {operator.email ? (
        <a className="text-accent underline" href={`mailto:${operator.email}`}>
          {operator.email}
        </a>
      ) : (
        <Fill value={null} label="e-mail" />
      )}
      .
    </>
  );
}
