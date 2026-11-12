import { Faq } from "@/components/landing/Faq";
import { FinalCta } from "@/components/landing/FinalCta";
import { ForTrainers } from "@/components/landing/ForTrainers";
import { Hero } from "@/components/landing/Hero";
import { SiteFooter } from "@/components/landing/SiteFooter";
import { SiteHeader } from "@/components/landing/SiteHeader";
import { TwoScreens } from "@/components/landing/TwoScreens";
import { IntroSplash } from "@/components/motion/IntroSplash";
import { introSeenScript } from "@/components/motion/introSeen";

export default function LandingPage() {
  return (
    <>
      <script dangerouslySetInnerHTML={{ __html: introSeenScript }} />
      <IntroSplash />
      <SiteHeader />
      <main>
        <Hero />
        <TwoScreens />
        <ForTrainers />
        <Faq />
        <FinalCta />
      </main>
      <SiteFooter />
    </>
  );
}
