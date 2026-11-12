import { LogDemo } from "./LogDemo";
import { StoreButtons } from "./StoreButtons";

export function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div aria-hidden className="hero-glow absolute inset-0" />
      <div aria-hidden className="hero-grid absolute inset-0" />

      <div className="relative mx-auto grid max-w-6xl items-center gap-14 px-4 pt-14 pb-24 sm:px-6 lg:grid-cols-[1.15fr_0.85fr] lg:pt-24 lg:pb-32">
        <div>
          <h1 className="font-display text-[clamp(2.6rem,7.2vw,5.6rem)] leading-[0.95] font-black tracking-[-0.035em]">
            Zapíš sériu.
            <br />
            Aj v suteréne bez signálu.
          </h1>
          <p className="mt-7 max-w-[34rem] text-lg leading-relaxed text-muted">
            Rejnox ti v mobile ukáže dnešný tréning od trénera, uloží každú sériu do telefónu a odošle ju, keď
            chytíš internet. Progres, rekordy a pripomienky máš na jednom mieste.
          </p>
          <StoreButtons className="mt-9" />
          <p className="mt-5 text-sm text-muted">Pre klientov aj trénerov. iPhone a Android.</p>
        </div>

        <LogDemo />
      </div>
    </section>
  );
}
