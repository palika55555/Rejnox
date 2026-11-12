import { NextResponse, type NextRequest } from "next/server";

/**
 * Rýchla kontrola pred vykreslením: bez cookie s reláciou ide návštevník
 * rovno na prihlásenie. Platnosť tokenu overí až stránka (src/lib/session.ts).
 */
export function proxy(request: NextRequest) {
  // Názov musí sedieť so SESSION_COOKIE v src/lib/session.ts.
  if (!request.cookies.has("rejnox_session")) {
    return NextResponse.redirect(new URL("/prihlasenie", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/prehlad/:path*"],
};
