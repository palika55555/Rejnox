import Image from "next/image";
import { IPhoneFrame } from "./phone/IPhoneFrame";

/** Skutočné obrazovky appky (public/app) s krátkym popisom. */
const shots = [
  {
    src: "/app/workout.webp",
    tag: "Tréning",
    title: "Séria za tri ťuknutia",
    text: "Veľké tlačidlá na opakovania aj váhu. Uloží sa aj bez signálu.",
    alt: "Zápis série v appke Rejnox",
  },
  {
    src: "/app/chat.webp",
    tag: "Chat",
    title: "Tréner je na správu ďaleko",
    text: "Pýtaš sa na plán, posielaš, ako to išlo. Odpoveď ti príde ako upozornenie.",
    alt: "Chat klientky s trénerom v appke Rejnox",
  },
  {
    src: "/app/calendar.webp",
    tag: "Kalendár",
    title: "Termíny bez telefonovania",
    text: "Voľné termíny trénera vidíš v mesiaci a miesto si rezervuješ hneď.",
    alt: "Kalendár tréningov u trénera v appke Rejnox",
  },
  {
    src: "/app/progress.webp",
    tag: "Progres",
    title: "Každé kilo navyše",
    text: "Objem po týždňoch, rekordy a partie, ktoré cvičíš najviac.",
    alt: "Progres a osobné rekordy v appke Rejnox",
  },
];

export function AppGallery() {
  return (
    <section id="appka" aria-labelledby="appka-title" className="sport-band relative overflow-hidden border-t border-line">
      <div aria-hidden className="sport-band__stripes absolute inset-0" />
      <div className="relative mx-auto max-w-6xl px-4 py-24 sm:px-6 lg:py-32">
        <div className="flex flex-wrap items-end justify-between gap-6">
          <h2
            id="appka-title"
            className="reveal max-w-2xl font-display text-[clamp(2.2rem,5.4vw,4.25rem)] leading-[0.95] font-black uppercase tracking-[-0.02em]"
          >
            Všetko v jednej appke. <span className="text-accent">Žiadne tabuľky.</span>
          </h2>
          <p className="reveal max-w-sm text-muted">
            Toto sú skutočné obrazovky Rejnoxu, žiadne návrhy. Tréning, tréner, termíny a progres na jednom mieste.
          </p>
        </div>

        <ul className="gallery reveal-stagger mt-16">
          {shots.map((shot, i) => (
            <li key={shot.src} className="gallery__item" style={{ ["--i" as string]: i }}>
              <div className="gallery__phone">
                <IPhoneFrame signal={{ label: "5G", offline: false }}>
                  <Image
                    src={shot.src}
                    alt={shot.alt}
                    fill
                    sizes="(min-width: 1024px) 15rem, 70vw"
                    className="object-cover object-top"
                  />
                </IPhoneFrame>
              </div>
              <p className="mt-6 text-xs font-bold tracking-[0.2em] text-accent uppercase">{shot.tag}</p>
              <h3 className="mt-1 font-display text-2xl font-extrabold uppercase">{shot.title}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-muted">{shot.text}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
