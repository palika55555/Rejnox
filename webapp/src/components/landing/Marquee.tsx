const items = [
  "Zápis bez internetu",
  "Plán od trénera",
  "Rekordy a progres",
  "Mapa fitiek",
  "Pripomienky tréningu",
  "Apple Health a Health Connect",
  "Pozývací kód pre klientov",
  "iPhone aj Android",
];

/** Nekonečný pás s funkciami appky medzi sekciami. */
export function Marquee() {
  const row = items.map((item) => (
    <li key={item} className="flex items-center gap-8 whitespace-nowrap">
      <span>{item}</span>
      <span className="size-1.5 rounded-full bg-brand-violet" />
    </li>
  ));
  return (
    <div className="marquee border-y border-line bg-surface/40 py-5">
      <p className="sr-only">{items.join(", ")}</p>
      <div aria-hidden className="marquee__track font-display text-lg font-extrabold text-muted sm:text-xl">
        <ul className="flex shrink-0 gap-8 pr-8">{row}</ul>
        <ul className="flex shrink-0 gap-8 pr-8">{row}</ul>
      </div>
    </div>
  );
}
