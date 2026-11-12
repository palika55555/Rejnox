import { storeLinks } from "@/lib/links";

const stores = [
  { name: "App Store", href: storeLinks.appStore, platform: "iPhone" },
  { name: "Google Play", href: storeLinks.googlePlay, platform: "Android" },
];

/** Tlačidlá do obchodov. Bez odkazu ukazujú, že appka príde čoskoro. */
export function StoreButtons({ className = "" }: { className?: string }) {
  return (
    <div className={`flex flex-wrap gap-3 ${className}`}>
      {stores.map((store) => {
        const inner = (
          <>
            <span className="block text-[11px] font-medium text-muted">
              {store.href ? `Stiahni pre ${store.platform} v` : `Pre ${store.platform} čoskoro v`}
            </span>
            <span className="block font-display text-lg font-extrabold leading-tight">{store.name}</span>
          </>
        );
        const base = "min-w-44 rounded-2xl border px-5 py-2.5 text-left";
        return store.href ? (
          <a
            key={store.name}
            href={store.href}
            className={`${base} border-line bg-surface transition-colors hover:border-accent`}
          >
            {inner}
          </a>
        ) : (
          <div key={store.name} className={`${base} border-dashed border-line`}>
            {inner}
          </div>
        );
      })}
    </div>
  );
}
