import Image from "next/image";
import Link from "next/link";
import { RejnoxMark } from "@/components/landing/RejnoxMark";

/**
 * Prihlásenie a registrácia ako v appke: fotka športovkyne v koralovom
 * svetle a formulár na tmavej karte. Na mobile je fotka hore za formulárom,
 * na počítači vpravo s veľkým sloganom.
 */
export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="grid min-h-screen lg:grid-cols-[1fr_0.95fr]">
      <div className="relative isolate flex flex-col overflow-hidden px-4 py-6 sm:px-10">
        {/* Mobil: fotka za formulárom, smerom dole zmizne do pozadia. */}
        <div aria-hidden className="absolute inset-x-0 top-0 -z-10 h-[60vh] lg:hidden">
          <Image
            src="/rejnox-athlete.webp"
            alt=""
            fill
            priority
            sizes="100vw"
            className="object-cover object-[50%_20%] opacity-70"
          />
          <div className="absolute inset-0 bg-gradient-to-b from-night/30 via-night/70 to-night" />
        </div>
        <div aria-hidden className="hero-glow absolute inset-0 -z-20" />

        <Link href="/" className="flex items-center gap-3 self-start" aria-label="Rejnox, späť na úvod">
          <RejnoxMark className="w-8" title="" />
          <span className="font-display text-base font-bold tracking-[0.32em]">REJNOX</span>
        </Link>
        <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-end pt-[22vh] pb-6 lg:justify-center lg:py-12">
          <div className="auth-card rounded-3xl border border-line bg-surface/85 p-6 shadow-2xl backdrop-blur-md sm:p-8 lg:border-0 lg:bg-transparent lg:p-0 lg:shadow-none lg:backdrop-blur-none">
            {children}
          </div>
        </main>
      </div>

      <div className="relative hidden overflow-hidden lg:block">
        <Image
          src="/rejnox-athlete.webp"
          alt=""
          fill
          priority
          sizes="48vw"
          className="object-cover object-[50%_30%]"
        />
        <div aria-hidden className="absolute inset-0 bg-gradient-to-t from-night via-night/10 to-transparent" />
        <div aria-hidden className="absolute inset-y-0 left-0 w-24 bg-gradient-to-r from-night to-transparent" />
        <div className="absolute inset-x-0 bottom-0 p-12">
          <span aria-hidden className="block h-1.5 w-16 rounded-full bg-accent" />
          <p className="mt-5 font-display text-[clamp(3rem,5vw,4.75rem)] leading-[0.9] font-black uppercase">
            Lepší pohyb.
            <br />
            <span className="text-accent">Zdravší ty.</span>
          </p>
          <p className="mt-4 max-w-sm text-muted">Tréningy, tréner a progres v jednej appke. Aj bez signálu.</p>
        </div>
      </div>
    </div>
  );
}
