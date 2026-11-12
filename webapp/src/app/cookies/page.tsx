import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, OperatorContact, Section } from "@/components/legal/LegalPage";
import { COOKIE_NOTICE_KEY } from "@/lib/legal";
import { INTRO_SEEN_KEY } from "@/components/motion/introSeen";
import { SESSION_COOKIE } from "@/lib/session";

export const metadata: Metadata = {
  title: "Cookies – Rejnox",
  description: "Aké cookies a úložisko prehliadača používa web Rejnox.",
};

const rows = [
  {
    name: SESSION_COOKIE,
    type: "Cookie (HttpOnly)",
    purpose: "Udrží ťa prihláseného. Vznikne až po prihlásení.",
    expiry: "30 dní alebo do odhlásenia",
  },
  {
    name: INTRO_SEEN_KEY,
    type: "sessionStorage",
    purpose: "Úvodná animácia sa v jednej návšteve ukáže len raz.",
    expiry: "Do zatvorenia karty",
  },
  {
    name: COOKIE_NOTICE_KEY,
    type: "localStorage",
    purpose: "Zapamätá si, že si zavrel lištu o cookies.",
    expiry: "Kým ho nezmažeš v prehliadači",
  },
  {
    name: "__cf_bm a podobné",
    type: "Cookie (Cloudflare)",
    purpose: "Ochrana webu pred botmi a útokmi. Nastavuje ich hosting, len ak je to potrebné.",
    expiry: "Najviac 30 minút",
  },
];

export default function CookiesPage() {
  return (
    <LegalPage
      title="Cookies"
      intro="Web Rejnox používa len cookies a úložisko prehliadača, ktoré sú nevyhnutné na jeho fungovanie a bezpečnosť. Žiadne reklamné ani analytické cookies, žiadne sledovanie."
    >
      <Section title="Čo sú cookies">
        <p>
          Cookies sú malé súbory, ktoré web uloží do tvojho prehliadača. Podobne funguje aj localStorage a
          sessionStorage. Pomáhajú webu zapamätať si napríklad to, že si prihlásený.
        </p>
      </Section>

      <Section title="Čo presne ukladáme">
        <div className="overflow-x-auto rounded-2xl border border-line">
          <table className="w-full min-w-[34rem] text-left text-sm">
            <thead className="bg-surface text-ink">
              <tr>
                <th className="px-4 py-3 font-semibold">Názov</th>
                <th className="px-4 py-3 font-semibold">Typ</th>
                <th className="px-4 py-3 font-semibold">Účel</th>
                <th className="px-4 py-3 font-semibold">Platnosť</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {rows.map((row) => (
                <tr key={row.name}>
                  <td className="px-4 py-3 font-mono text-xs text-ink">{row.name}</td>
                  <td className="px-4 py-3">{row.type}</td>
                  <td className="px-4 py-3">{row.purpose}</td>
                  <td className="px-4 py-3">{row.expiry}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p>
          Písma sú uložené priamo na našom serveri, takže sa pri návšteve nič neposiela Googlu ani iným tretím
          stranám.
        </p>
      </Section>

      <Section title="Prečo nežiadame súhlas">
        <p>
          Všetky položky vyššie sú nevyhnutné na poskytnutie služby, o ktorú žiadaš (prihlásenie, bezpečnosť,
          základné fungovanie webu). Podľa § 109 ods. 8 zákona č. 452/2021 Z. z. o elektronických komunikáciách a
          smernice ePrivacy na ne súhlas nie je potrebný. Lišta o cookies ťa o nich len informuje.
        </p>
        <p>
          Ak by sme niekedy pridali analytické alebo marketingové cookies, najprv ťa požiadame o súhlas a
          umožníme ho kedykoľvek odvolať.
        </p>
      </Section>

      <Section title="Ako cookies vymazať alebo zablokovať">
        <p>
          Cookies a úložisko môžeš kedykoľvek vymazať alebo zablokovať v nastaveniach prehliadača. Bez cookie{" "}
          <span className="font-mono text-xs text-ink">{SESSION_COOKIE}</span> sa však neprihlásiš.
        </p>
      </Section>

      <Section title="Kontakt">
        <p>
          <OperatorContact />
        </p>
        <p>
          Viac o spracúvaní údajov nájdeš v{" "}
          <Link className="text-accent underline" href="/ochrana-osobnych-udajov">
            zásadách ochrany osobných údajov
          </Link>
          .
        </p>
      </Section>
    </LegalPage>
  );
}
