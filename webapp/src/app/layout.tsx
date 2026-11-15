import type { Metadata, Viewport } from "next";
import { Big_Shoulders, Onest } from "next/font/google";
import { CookieNotice } from "@/components/legal/CookieNotice";
import "./globals.css";
import "./motion.css";
import "./landing.css";

// Rovnaké písma ako mobilná appka: zúžené športové nadpisy a čitateľný text.
const bigShoulders = Big_Shoulders({
  variable: "--font-big-shoulders",
  subsets: ["latin", "latin-ext"],
  weight: ["700", "800", "900"],
});

const onest = Onest({
  variable: "--font-onest",
  subsets: ["latin", "latin-ext"],
});

export const metadata: Metadata = {
  title: "Rejnox – tréningy, tréneri a klienti v jednej appke",
  description:
    "Zapisuj série aj bez internetu, maj plán od trénera v mobile a sleduj progres. Rejnox pre iPhone a Android.",
  openGraph: {
    title: "Rejnox – lepší pohyb, zdravší ty",
    description: "Tréningy, tréneri a klienti v jednej appke.",
    locale: "sk_SK",
    type: "website",
    images: ["/rejnox-athlete.webp"],
  },
};

export const viewport: Viewport = {
  themeColor: "#06061a",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    // suppressHydrationWarning: skript úvodu pridá na <html> atribút ešte pred Reactom.
    <html lang="sk" className={`${bigShoulders.variable} ${onest.variable} h-full`} suppressHydrationWarning>
      <body className="min-h-full">
        {children}
        <CookieNotice />
      </body>
    </html>
  );
}
