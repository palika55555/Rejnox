const steps = [
  {
    title: "Pridaj klienta",
    text: "Stačí meno. Klient nemusí mať appku, plány a progres mu môžeš viesť aj tak.",
  },
  {
    title: "Pošli mu kód",
    text: "Kód sa zobrazí len raz. Ak ho klient stratí, vytvoríš nový jedným ťuknutím.",
    code: "K7QM-4XPA",
  },
  {
    title: "Klient zadá kód v appke",
    text: "V Profile ťukne na Mám kód od trénera. Odvtedy vidí tvoje plány a ty jeho série.",
  },
];

export function ForTrainers() {
  return (
    <section id="pre-trenerov" className="border-t border-line bg-surface/40">
      <div className="mx-auto max-w-6xl px-4 py-24 sm:px-6 lg:py-32">
        <div className="grid gap-6 lg:grid-cols-[1fr_1fr] lg:items-end">
          <h2 className="font-display text-[clamp(2rem,4.6vw,3.5rem)] leading-[1.02] font-black tracking-[-0.03em]">
            Pre trénerov: klient prepojený za minútu.
          </h2>
          <p className="max-w-[34rem] text-lg leading-relaxed text-muted lg:justify-self-end">
            Pozývací kód namiesto tabuliek a správ. Píšeš plány, vidíš odcvičené série a môžeš klientovi sériu
            zapísať aj sám, keď cvičíte spolu.
          </p>
        </div>

        <ol className="mt-16 grid gap-px overflow-hidden rounded-3xl border border-line bg-line md:grid-cols-3">
          {steps.map((step, i) => (
            <li key={step.title} className="flex flex-col bg-night p-7 sm:p-8">
              <span className="font-display text-6xl leading-none font-black text-surface-hi">{i + 1}</span>
              <h3 className="mt-6 font-display text-xl font-extrabold">{step.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted">{step.text}</p>
              {step.code && (
                <p
                  className="mt-6 self-start rounded-xl border border-accent/50 bg-surface-hi px-4 py-2.5 font-mono text-2xl font-bold tracking-[0.12em] text-accent"
                  aria-label={`Príklad kódu: ${step.code}`}
                >
                  {step.code}
                </p>
              )}
            </li>
          ))}
        </ol>

        <p className="mt-8 max-w-[40rem] text-sm leading-relaxed text-muted">
          Spoluprácu môže ukončiť tréner aj klient. Tréner potom stratí prístup k plánom a progresu, klientovi
          jeho história ostane.
        </p>
      </div>
    </section>
  );
}
