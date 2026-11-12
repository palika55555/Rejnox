const questions = [
  {
    q: "Funguje Rejnox bez internetu?",
    a: "Áno. Série sa uložia v telefóne a odošlú sa na server, keď sa pripojíš. Každá séria má vlastné ID, takže sa nič nezapíše dvakrát.",
  },
  {
    q: "Musí mať môj klient appku?",
    a: "Nie. Klienta pridáš len s menom a plány aj progres mu vedieš sám. Keď si appku stiahne, zadá kód a uvidí všetko, čo si mu pripravil.",
  },
  {
    q: "Čo sa stane, keď ukončím spoluprácu s trénerom?",
    a: "Tréner stratí prístup k tvojim plánom a progresu. Tvoja história tréningov ti ostane.",
  },
  {
    q: "Ako fungujú pripomienky?",
    a: "V mobilnej appke si nastavíš čas a Rejnox ti každý deň pripomenie tréning. Pripomienky fungujú na iPhone aj Android.",
  },
  {
    q: "Kedy bude verzia na počítač?",
    a: "Pripravujeme ju. Pribudnú v nej jedálničky, štatistiky progresu a správa klientov pre trénerov. Prihlásiš sa rovnakým účtom ako v mobile.",
  },
];

export function Faq() {
  return (
    <section id="otazky" className="border-t border-line">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-24 sm:px-6 lg:grid-cols-[0.8fr_1.2fr] lg:py-32">
        <h2 className="reveal font-display text-[clamp(2rem,4.6vw,3.5rem)] leading-[1.02] font-black tracking-[-0.03em]">
          Časté otázky
        </h2>
        <div className="reveal-stagger divide-y divide-line border-y border-line">
          {questions.map((item) => (
            <details key={item.q} className="group py-5">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 font-semibold [&::-webkit-details-marker]:hidden">
                {item.q}
                <span
                  aria-hidden
                  className="grid size-7 shrink-0 place-items-center rounded-full border border-line text-muted transition-transform group-open:rotate-45"
                >
                  +
                </span>
              </summary>
              <p className="mt-3 max-w-[38rem] leading-relaxed text-muted">{item.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
