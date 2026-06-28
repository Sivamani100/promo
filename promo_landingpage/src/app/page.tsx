import { Metadata } from "next";
import { generateMetadata } from "@/lib/seo/metadata";
import { SEO_CONFIGS } from "@/lib/seo/metadata";
import { 
  OrganizationStructuredData,
  WebSiteStructuredData,
  FAQStructuredData,
  WebApplicationStructuredData,
  SearchActionStructuredData
} from "@/components/seo/structured-data";
import HomePageClient from "@/components/homepage/homepage-client";

export const metadata: Metadata = generateMetadata(SEO_CONFIGS.HOME);

export default function LandingPage() {
  return (
    <>
      {/* Comprehensive Structured Data for SEO */}
      <OrganizationStructuredData />
      <WebSiteStructuredData />
      <WebApplicationStructuredData />
      <SearchActionStructuredData />
      <FAQStructuredData faqs={[
        { question: "How much does it cost to use Promo?", answer: "Listing your campaigns and matching with creators is 100% free. There are no registration fees or hidden monthly costs." },
        { question: "Do influencers need to submit verification documents?", answer: "Yes. Influencers submit verification data to obtain a badge, ensuring only verified creators with actual organic reach apply to campaigns." },
        { question: "How does the language selection help my campaigns?", answer: "When creating a Campaign Card, brands can specify required languages (e.g. Hindi, Telugu, Tamil). Influencers instantly see these requirements, ensuring authentic localized reach." },
        { question: "Is my brand and chat data safe?", answer: "Absolutely. We use Supabase secure infrastructure with strict Row-Level Security. Data is only accessible to campaign participants, and is permanently deleted on account removal." },
        { question: "How do I get started as a Brand or Influencer?", answer: "Click the 'Open Web App' button, sign up with your email or Google, select your role (Brand or Influencer), and launch your first card or profile in minutes!" }
      ]} />
      
      {/* Client Component for Interactive Elements */}
      <HomePageClient />
    </>
  );
}

