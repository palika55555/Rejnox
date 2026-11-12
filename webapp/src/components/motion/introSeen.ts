/** Kľúč v sessionStorage: úvod sa v jednej návšteve ukáže len raz. */
export const INTRO_SEEN_KEY = "rejnox-intro-seen";

/**
 * Skript, ktorý beží ešte pred vykreslením stránky. Ak návštevník úvod už
 * videl alebo má zapnutý znížený pohyb, skryje ho, aby len nepreblikol.
 */
export const introSeenScript = `try{if(sessionStorage.getItem(${JSON.stringify(INTRO_SEEN_KEY)})||matchMedia("(prefers-reduced-motion: reduce)").matches){document.documentElement.setAttribute("data-intro-seen","")}}catch(e){}`;
