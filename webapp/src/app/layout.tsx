import type { Metadata, Viewport } from "next";
import { Inter, Montserrat } from "next/font/google";
import "./globals.css";
import "./motion.css";

const montserrat = Montserrat({
  variable: "--font-montserrat",
  subsets: ["latin", "latin-ext"],
  weight: ["700", "800", "900"],
});

const inter = Inter({
  variable: "--font-inter",
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
    images: ["/rejnox-poster.webp"],
  },
};

export const viewport: Viewport = {
  themeColor: "#06061a",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    // suppressHydrationWarning: skript úvodu pridá na <html> atribút ešte pred Reactom.
    <html lang="sk" className={`${montserrat.variable} ${inter.variable} h-full`} suppressHydrationWarning>
      <body className="min-h-full">{children}</body>
    </html>
  );
}
