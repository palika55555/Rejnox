import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, OperatorContact, Section } from "@/components/legal/LegalPage";

export const metadata: Metadata = {
  title: "Ochrana osobných údajov – Rejnox",
  description: "Aké osobné údaje Rejnox spracúva, prečo, ako dlho a aké máš práva.",
};

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Ochrana osobných údajov"
      intro="Stručne a zrozumiteľne: aké údaje o tebe Rejnox spracúva, na čo ich potrebuje, komu ich odovzdáva a aké máš práva. Platí pre web aj mobilnú appku."
    >
      <Section title="1. Kto je prevádzkovateľ">
        <p>
          <OperatorContact />
        </p>
        <p>
          Údaje spracúvame podľa nariadenia (EÚ) 2016/679 (GDPR) a zákona č. 18/2018 Z. z. o ochrane osobných
          údajov. Zodpovednú osobu sme nevymenovali, pretože nám to zákon neukladá.
        </p>
      </Section>

      <Section title="2. Aké údaje spracúvame a prečo">
        <ul>
          <li>
            <b>Účet</b> – e-mail, meno, ktoré si zvolíš, rola (klient alebo tréner), heslo uložené len ako
            bezpečný odtlačok (hash), voliteľne mesto. Bez nich nevieme vytvoriť a prevádzkovať tvoj účet.
            Právny základ: plnenie zmluvy (čl. 6 ods. 1 písm. b GDPR).
          </li>
          <li>
            <b>Tréningy</b> – plány, cviky, série, opakovania, váhy, rekordy a týždenné ciele. Sú to údaje, ktoré
            do appky sám zadáš, aby si mohol sledovať progres. Právny základ: plnenie zmluvy.
          </li>
          <li>
            <b>Spolupráca s trénerom</b> – prepojenie klienta a trénera, správy, rezervácie a permanentky.
            Tréner vidí tvoje plány a série len kým ste prepojení; spoluprácu môžeš kedykoľvek ukončiť. Právny
            základ: plnenie zmluvy.
          </li>
          <li>
            <b>Fitká a hodnotenia</b> – hodnotenia fitiek, ktoré napíšeš. Účasť v rebríčkoch je vypnutá, kým ju
            sám nezapneš. Právny základ: plnenie zmluvy, pri rebríčkoch tvoj súhlas (čl. 6 ods. 1 písm. a).
          </li>
          <li>
            <b>Prihlásenie a bezpečnosť</b> – relácie prihlásenia (platné 30 dní) a počítadlá pokusov proti
            hádaniu hesiel. Počítadlá ukladáme len ako jednosmerný odtlačok, nie ako IP adresu či e-mail.
            Právny základ: oprávnený záujem na bezpečnosti služby (čl. 6 ods. 1 písm. f).
          </li>
        </ul>
      </Section>

      <Section title="3. Údaje, ktoré ostávajú len v tvojom telefóne">
        <ul>
          <li>
            <b>Zdravotné údaje</b> z Apple Health alebo Health Connect (napr. tep, kroky) appka len číta a
            zobrazuje v telefóne, a to iba ak to v systéme povolíš. Na náš server ich neposielame.
          </li>
          <li>
            <b>Poloha</b> slúži len na zobrazenie fitiek v okolí na mape. Vzdialenosti sa počítajú v telefóne,
            polohu neukladáme. Prístup môžeš kedykoľvek vypnúť v nastaveniach telefónu.
          </li>
          <li>
            <b>Pripomienky tréningu</b> plánuje priamo telefón, bez nášho servera.
          </li>
        </ul>
      </Section>

      <Section title="4. Komu údaje odovzdávame">
        <p>Údaje nepredávame a nepoužívame na reklamu. Pomáhajú nám len títo sprostredkovatelia:</p>
        <ul>
          <li>
            <b>Cloudflare, Inc.</b> – hosting webu a servera appky, ochrana pred útokmi.
          </li>
          <li>
            <b>Poskytovateľ databázy (Supabase)</b> – bezpečné uloženie údajov účtu a tréningov.
          </li>
          <li>
            <b>OpenStreetMap Foundation</b> – podklady mapy v appke. Pri načítaní mapy telefón stiahne dlaždice
            z ich servera, ktorý tak vidí tvoju IP adresu a zobrazenú oblasť.
          </li>
        </ul>
        <p>
          Ak sa údaje dostanú mimo EÚ (napr. do USA), deje sa tak na základe rozhodnutia Európskej komisie o
          primeranosti (EU–US Data Privacy Framework) alebo štandardných zmluvných doložiek. Appku sťahuješ z App
          Store alebo Google Play – tie spracúvajú údaje podľa vlastných zásad.
        </p>
      </Section>

      <Section title="5. Ako dlho údaje uchovávame">
        <ul>
          <li>Údaje účtu a tréningov, kým máš účet. Po zmazaní účtu ich bez zbytočného odkladu vymažeme.</li>
          <li>Relácie prihlásenia 30 dní, alebo kým sa neodhlásiš.</li>
          <li>Počítadlá pokusov len počas krátkeho časového okna (minúty až hodiny).</li>
          <li>Ak spoluprácu s trénerom ukončíš, tréner stratí prístup a tvoja história ostane len tebe.</li>
        </ul>
      </Section>

      <Section title="6. Tvoje práva">
        <p>Kedykoľvek máš právo:</p>
        <ul>
          <li>na prístup k svojim údajom a ich kópiu,</li>
          <li>na opravu nesprávnych údajov,</li>
          <li>na vymazanie („byť zabudnutý“) – účet zmažeš aj sám v appke,</li>
          <li>na obmedzenie spracúvania a na prenosnosť údajov,</li>
          <li>namietať spracúvanie založené na oprávnenom záujme,</li>
          <li>kedykoľvek odvolať súhlas (napr. vypnúť rebríčky) bez vplyvu na skoršie spracúvanie,</li>
          <li>
            podať sťažnosť na Úrad na ochranu osobných údajov SR, Hraničná 12, 820 07 Bratislava,{" "}
            <a className="text-accent underline" href="https://dataprotection.gov.sk" rel="noreferrer" target="_blank">
              dataprotection.gov.sk
            </a>
            .
          </li>
        </ul>
        <p>Žiadosť vybavíme bezplatne, najneskôr do jedného mesiaca.</p>
      </Section>

      <Section title="7. Bezpečnosť a vek">
        <p>
          Spojenie je šifrované (HTTPS), heslá ukladáme len ako odtlačok a prístup k databáze je obmedzený na
          nevyhnutné minimum. Neprijímame automatizované rozhodnutia ani profilovanie s právnymi účinkami.
        </p>
        <p>Rejnox je určený pre osoby od 16 rokov.</p>
      </Section>

      <Section title="8. Cookies a zmeny zásad">
        <p>
          Používame len nevyhnutné cookies, podrobnosti nájdeš na stránke{" "}
          <Link className="text-accent underline" href="/cookies">
            Cookies
          </Link>
          . Ak tieto zásady zmeníme, aktualizujeme dátum hore a pri podstatných zmenách ťa upozorníme v appke.
        </p>
      </Section>
    </LegalPage>
  );
}
