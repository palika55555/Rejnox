import Image from "next/image";
import { StoreButtons } from "./StoreButtons";

export function FinalCta() {
  return (
    <section id="stiahnut" className="border-t border-line">
      <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 py-24 sm:px-6 md:grid-cols-[0.8fr_1.2fr] lg:py-32">
        <div className="reveal glow-card relative mx-auto aspect-[941/1672] w-full max-w-xs overflow-hidden rounded-3xl border border-line">
          <Image
            src="/rejnox-poster.webp"
            alt="Rejnox – lepší pohyb, zdravší ty"
            fill
            sizes="(min-width: 768px) 320px, 80vw"
            className="object-cover"
          />
        </div>
        <div className="reveal">
          <h2 className="font-display text-[clamp(2.4rem,6vw,4.75rem)] leading-[0.98] font-black tracking-[-0.035em]">
            Lepší pohyb, <span className="text-shimmer">zdravší ty.</span>
          </h2>
          <p className="mt-6 max-w-[32rem] text-lg leading-relaxed text-muted">
            Stiahni si Rejnox do mobilu. Ak máš trénera, popros ho o kód a jeho plán uvidíš hneď po prihlásení.
          </p>
          <StoreButtons className="mt-9" />
        </div>
      </div>
    </section>
  );
}
