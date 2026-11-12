// Rejnox API pre mobilnú appku (Flutter): https://<doména>/api/...
// Cesty a odpovede sú rovnaké, aké mal pôvodný Dart server (server/).
import { withDb } from "@/server/db";
import { handleApi } from "@/server/router";

function handle(request: Request): Promise<Response> {
  const path = new URL(request.url).pathname.replace(/^\/api(?=\/|$)/, "") || "/";
  return handleApi(request, path, { connect: withDb });
}

export { handle as GET, handle as POST, handle as PUT, handle as DELETE, handle as OPTIONS };
