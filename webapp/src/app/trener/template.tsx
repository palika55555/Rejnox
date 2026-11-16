import { ViewTransition } from "react";

/**
 * Šablóna sa pri každej navigácii v trénerskej zóne pripojí nanovo, takže
 * prechod sa spustí pri každom kliknutí. Smer podľa typu odkazu
 * (nav-forward / nav-back), inak jemné vynorenie.
 */
export default function TrainerTemplate({ children }: { children: React.ReactNode }) {
  return (
    <ViewTransition
      enter={{ "nav-forward": "nav-forward", "nav-back": "nav-back", default: "page" }}
      exit={{ "nav-forward": "nav-forward", "nav-back": "nav-back", default: "page" }}
      default="none"
    >
      <div>{children}</div>
    </ViewTransition>
  );
}
