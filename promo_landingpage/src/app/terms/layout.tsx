import type { Metadata } from "next";

const BASE_URL = "https://Promo.arkio.in";

export const metadata: Metadata = {
  title: "Terms of Service — Promo Print Platform | Promo",
  description:
    "Promo's terms of service for using our free online xerox and document printing platform. Understand your rights, our responsibilities, and usage guidelines.",
  alternates: { canonical: `${BASE_URL}/terms` },
  robots: { index: true, follow: false },
  openGraph: {
    title: "Promo Terms of Service",
    description: "Terms for using Promo's free online xerox and print platform.",
    url: `${BASE_URL}/terms`,
  },
};

export default function TermsLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
