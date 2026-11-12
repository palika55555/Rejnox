import { HeroPhone } from "./phone/HeroPhone";
import { StoreButtons } from "./StoreButtons";

export function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div aria-hidden className="hero-glow absolute inset-0" />
      <div aria-hidden className="aurora absolute inset-0">
        <span className="aurora__blob aurora__blob--a" />
        <span className="aurora__blob aurora__blob--b" />
        <span className="aurora__blob aurora__blob--c" />
      </div>
      <div aria-hidden className="hero-grid absolute inset-0" />

      <div className="relative mx-auto grid max-w-6xl items-center gap-14 px-4 pt-14 pb-24 sm:px-6 lg:grid-cols-[1.15fr_0.85fr] lg:pt-20 lg:pb-28">
        <div>
          <p className="hero-in inline-flex items-center gap-2 rounded-full border border-line bg-surface/90 px-3 py-1 text-xs font-semibold text-muted" style={{ ["--d" as string]: "0ms" }}>
            <span className="live-dot" aria-hidden />
            Funguje aj offline
          </p>
          <h1 className="mt-6 font-display text-[clamp(2.6rem,7.2vw,5.6rem)] leading-[0.95] font-black tracking-[-0.035em]">
            <span className="hero-line">
              <span className="hero-in" style={{ ["--d" as string]: "80ms" }}>
                Zapíš sériu.
              </span>
            </span>
            <span className="hero-line">
              <span className="hero-in" style={{ ["--d" as string]: "200ms" }}>
                Aj v suteréne
              </span>
            </span>
            <span className="hero-line">
              <span className="hero-in text-shimmer" style={{ ["--d" as string]: "320ms" }}>
                bez signálu.
              </span>
            </span>
          </h1>
          <p className="hero-in mt-7 max-w-[34rem] text-lg leading-relaxed text-muted" style={{ ["--d" as string]: "460ms" }}>
            Rejnox ti v mobile ukáže dnešný tréning od trénera, uloží každú sériu do telefónu a odošle ju, keď
            chytíš internet. Progres, rekordy a pripomienky máš na jednom mieste.
          </p>
          <div className="hero-in" style={{ ["--d" as string]: "580ms" }}>
            <StoreButtons className="mt-9" />
          </div>
          <p className="hero-in mt-5 text-sm text-muted" style={{ ["--d" as string]: "680ms" }}>
            Pre klientov aj trénerov. iPhone a Android.
          </p>
        </div>

        <div className="hero-in hero-in--phone" style={{ ["--d" as string]: "250ms" }}>
          <HeroPhone />
        </div>
      </div>
    </section>
  );
}
