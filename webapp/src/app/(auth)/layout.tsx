import Image from "next/image";
import Link from "next/link";
import { RejnoxMark } from "@/components/landing/RejnoxMark";

export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="grid min-h-screen lg:grid-cols-[1fr_0.9fr]">
      <div className="relative flex flex-col px-4 py-6 sm:px-10">
        <div aria-hidden className="hero-glow absolute inset-0 -z-10" />
        <Link href="/" className="flex items-center gap-3 self-start" aria-label="Rejnox, späť na úvod">
          <RejnoxMark className="w-8" title="" />
          <span className="font-display text-sm font-bold tracking-[0.32em]">REJNOX</span>
        </Link>
        <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center py-12">{children}</main>
      </div>
      <div className="relative hidden overflow-hidden border-l border-line lg:block">
        <Image
          src="/rejnox-poster.webp"
          alt=""
          fill
          priority
          sizes="45vw"
          className="object-cover object-[50%_35%]"
        />
      </div>
    </div>
  );
}
