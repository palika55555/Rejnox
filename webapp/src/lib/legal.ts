/**
 * Údaje o prevádzkovateľovi pre zásady ochrany osobných údajov a cookies.
 * Povinné podľa čl. 13 GDPR – pred spustením doplň skutočné údaje.
 * Kým nie je firma, prevádzkovateľom je fyzická osoba: stačí meno a e-mail,
 * IČO a adresu nechaj null (na stránke sa potom vôbec neukážu).
 * Ak chýba meno, stránka ukáže zvýraznené „doplniť“.
 */
export const operator: {
  name: string | null;
  ico: string | null;
  address: string | null;
  email: string | null;
} = {
  name: "Pavol Domonkoš",
  ico: null,
  address: null,
  email: "support@rejnox.sk",
};

/** Dátum poslednej zmeny dokumentov (zobrazí sa na stránkach). */
export const legalUpdatedAt = "12. 11. 2026";

/** Kľúč v localStorage: návštevník zavrel lištu o cookies. */
export const COOKIE_NOTICE_KEY = "rejnox-cookie-notice";
