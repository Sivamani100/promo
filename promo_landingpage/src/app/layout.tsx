import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import { Analytics } from "@vercel/analytics/react";
import { SpeedInsights } from "@vercel/speed-insights/next";
import "./globals.css";
import "@/lib/env";

const inter = Inter({ subsets: ["latin"] });

const BASE_URL = "https://Promo.arkio.in";

export const metadata: Metadata = {
  metadataBase: new URL(BASE_URL),

  // ── Core Identity ─────────────────────────────────────────────────────────
  title: {
    default: "Promo | Premium Influencer Marketing Marketplace",
    template: "%s | Promo",
  },
  description:
    "Promo connects brands and content creators. Post campaign cards, set targeting requirements, match with elite creators, and track your metrics in real-time.",
  keywords: [
    "influencer marketplace",
    "influencer marketing",
    "content creator collaborations",
    "brand sponsorships",
    "creator portfolio",
    "Instagram influencer marketing",
    "YouTube sponsorships",
    "campaign management",
    "Promo",
    "creator marketplace India",
    "influencer network",
  ],

  // ── Canonical ─────────────────────────────────────────────────────────────
  alternates: {
    canonical: BASE_URL,
  },

  // ── PWA / Icons ───────────────────────────────────────────────────────────
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Promo",
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/ion_print.png", type: "image/png", sizes: "192x192" },
    ],
    apple: [
      { url: "/ion_print.png", sizes: "180x180", type: "image/png" },
    ],
    shortcut: "/ion_print.png",
  },

  // ── Open Graph ────────────────────────────────────────────────────────────
  openGraph: {
    title: "Promo | Premium Influencer Marketing Marketplace",
    description:
      "Promo connects brands and content creators. Post campaign cards, set targeting requirements, match with elite creators, and track your metrics in real-time.",
    url: BASE_URL,
    siteName: "Promo",
    locale: "en_IN",
    type: "website",
    images: [
      {
        url: `${BASE_URL}/og-image.svg`,
        width: 1200,
        height: 630,
        alt: "Promo — Premium Influencer Marketing Marketplace",
      },
    ],
  },

  // ── Twitter / X Card ─────────────────────────────────────────────────────
  twitter: {
    card: "summary_large_image",
    title: "Promo | Premium Influencer Marketing Marketplace",
    description:
      "Promo connects brands and content creators. Post campaign cards, set targeting requirements, match with elite creators, and track your metrics in real-time.",
    images: [`${BASE_URL}/og-image.svg`],
  },

  // ── Robots ────────────────────────────────────────────────────────────────
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },

  // ── Category ─────────────────────────────────────────────────────────────
  category: "technology",
};

export const viewport: Viewport = {
  themeColor: "#000000",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
};

import { CookieConsent } from "@/components/layout/cookie-consent";
import Script from "next/script";
import {
  OrganizationJsonLd,
  WebSiteJsonLd,
} from "@/components/seo/json-ld";
import { MaintenanceGuard } from "@/components/layout/maintenance-guard";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en-IN" className="dark" suppressHydrationWarning>
      <head>
        {/* ── Structured Data (JSON-LD) ── */}
        <OrganizationJsonLd />
        <WebSiteJsonLd />
      </head>
      <body className={`${inter.className} min-h-screen antialiased selection:bg-brand-primary/30`}>

        {/* ── Google Analytics 4 (GA4) ──────────────────────────────────────────
            Measurement ID: G-9HSQS64CK5
            strategy="afterInteractive" fires after page hydration — zero
            impact on LCP / CLS / FID Core Web Vitals scores.
            Placed in root layout = automatically fires on EVERY page. ────── */}
        <Script
          src="https://www.googletagmanager.com/gtag/js?id=G-9HSQS64CK5"
          strategy="afterInteractive"
        />
        <Script id="google-analytics" strategy="afterInteractive">
          {`
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', 'G-9HSQS64CK5', {
              page_path: window.location.pathname,
              send_page_view: true
            });
          `}
        </Script>

        <MaintenanceGuard>
          {children}
        </MaintenanceGuard>
        <Analytics />
        <SpeedInsights />
        <CookieConsent />
      </body>
    </html>
  );
}
