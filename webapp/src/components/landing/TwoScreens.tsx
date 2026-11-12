import { DesktopMock } from "./DesktopMock";

const phone = [
  { title: "Dnešný tréning", text: "Plán od trénera s cvikmi, sériami a váhami. Otvoríš a cvičíš." },
  { title: "Zápis aj bez internetu", text: "Série sa uložia v telefóne a odošlú sa samy, keď chytíš signál." },
  { title: "Pripomienka tréningu", text: "Každý deň v čase, ktorý si zvolíš. Na iPhone aj Android." },
  { title: "Týždenný cieľ a rekordy", text: "Vidíš, koľko tréningov ti chýba a kde si posunul maximum." },
];

const desktop = [
  { title: "Jedálničky a makrá", text: "Poskladáš celý týždeň jedál a hneď vidíš kalórie aj bielkoviny." },
  { title: "Štatistiky progresu", text: "Objem, rekordy a pravidelnosť po týždňoch, podľa svalových partií." },
  { title: "Plány pre klientov", text: "Tréner pripraví plány pre všetkých klientov naraz, na veľkej obrazovke." },
];

export function TwoScreens() {
  return (
    <section id="na-pocitaci" className="border-t border-line">
      <div className="mx-auto max-w-6xl px-4 py-24 sm:px-6 lg:py-32">
        <h2 className="reveal max-w-3xl font-display text-[clamp(2rem,4.6vw,3.5rem)] leading-[1.02] font-black tracking-[-0.03em]">
          Vo fitku v mobile. Doma na počítači.
        </h2>
        <p className="reveal mt-5 max-w-[38rem] text-lg leading-relaxed text-muted">
          V gyme potrebuješ zapísať sériu za pár sekúnd. Plánovať týždeň, skladať jedálniček a pozerať progres je
          pohodlnejšie na veľkej obrazovke. Jeden účet, rovnaké dáta.
        </p>

        <div className="mt-16 grid gap-14 lg:grid-cols-[0.75fr_1.25fr] lg:gap-16">
          <div>
            <h3 className="font-display text-xl font-extrabold">V mobile</h3>
            <dl className="reveal-stagger mt-6 space-y-6">
              {phone.map((item) => (
                <div key={item.title} className="border-l-2 border-brand-violet pl-4">
                  <dt className="font-semibold">{item.title}</dt>
                  <dd className="mt-1 text-sm leading-relaxed text-muted">{item.text}</dd>
                </div>
              ))}
            </dl>
          </div>

          <div>
            <div className="flex flex-wrap items-center gap-3">
              <h3 className="font-display text-xl font-extrabold">Na počítači</h3>
              <span className="rounded-full border border-flame/40 px-2.5 py-0.5 text-xs font-semibold text-flame">
                Pripravujeme
              </span>
            </div>
            <div className="reveal mt-6">
              <DesktopMock />
            </div>
            <dl className="reveal-stagger mt-8 grid gap-6 sm:grid-cols-3">
              {desktop.map((item) => (
                <div key={item.title}>
                  <dt className="font-semibold">{item.title}</dt>
                  <dd className="mt-1 text-sm leading-relaxed text-muted">{item.text}</dd>
                </div>
              ))}
            </dl>
          </div>
        </div>
      </div>
    </section>
  );
}
