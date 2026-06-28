import { Metadata } from 'next';

export interface SEOConfig {
  title: string;
  description: string;
  keywords?: string[];
  canonical?: string;
  noindex?: boolean;
  nofollow?: boolean;
  openGraph?: {
    title?: string;
    description?: string;
    url?: string;
    type?: 'website' | 'article' | 'product';
    images?: Array<{
      url: string;
      width?: number;
      height?: number;
      alt?: string;
    }>;
  };
  twitter?: {
    card?: 'summary' | 'summary_large_image';
    title?: string;
    description?: string;
    images?: string[];
  };
  alternate?: {
    canonical?: string;
    languages?: Record<string, string>;
  };
  jsonLd?: Record<string, any>[];
}

const BASE_URL = 'https://Promo.arkio.in';

export function generateMetadata(config: SEOConfig): Metadata {
  const {
    title,
    description,
    keywords = [],
    canonical,
    noindex = false,
    nofollow = false,
    openGraph,
    twitter,
    alternate,
    jsonLd
  } = config;

  const canonicalUrl = canonical || BASE_URL;
  
  // Default OpenGraph config
  const defaultOpenGraph = {
    title: title,
    description: description,
    url: canonicalUrl,
    siteName: 'Promo',
    locale: 'en_IN',
    type: 'website' as const,
    images: [
      {
        url: `${BASE_URL}/og-image.svg`,
        width: 1200,
        height: 630,
        alt: title,
      },
    ],
  };

  // Default Twitter config
  const defaultTwitter = {
    card: 'summary_large_image' as const,
    title: title,
    description: description,
    images: [`${BASE_URL}/og-image.svg`],
  };

  return {
    title: {
      default: title,
      template: '%s | Promo',
    },
    description,
    keywords: keywords.join(', '),
    authors: [{ name: 'Promo Team' }],
    creator: 'Promo Team',
    publisher: 'Promo',
    robots: {
      index: !noindex,
      follow: !nofollow,
      googleBot: {
        index: !noindex,
        follow: !nofollow,
        'max-video-preview': -1,
        'max-image-preview': 'large',
        'max-snippet': -1,
      },
    },
    openGraph: { ...defaultOpenGraph, ...openGraph },
    twitter: { ...defaultTwitter, ...twitter },
    alternates: {
      canonical: canonicalUrl,
      ...alternate,
    },
    metadataBase: new URL(BASE_URL),
    verification: {
      google: 'zAZIwBcueJ0zXcjzyVS-DexvshYM0ImpIiSwVEodrsY',
    },
    other: {
      jsonLd: jsonLd ? JSON.stringify(jsonLd) : undefined,
    } as Record<string, any>,
  };
}

// Predefined SEO configs for different page types
export const SEO_CONFIGS = {
  HOME: {
    title: 'Promo | Premium Influencer Marketing Marketplace',
    description: 'Promo connects brands and content creators. Post campaign cards, set targeting requirements, match with elite creators, and track metrics in real-time.',
    keywords: [
      'influencer marketplace',
      'creator marketplace',
      'brand sponsorships',
      'influencer marketing',
      'creator collaborations',
      'Promo',
      'campaign cards',
      'creator portfolio',
      'Instagram influencer marketing',
      'YouTube sponsorships',
    ],
    openGraph: {
      type: 'website' as const,
    },
  },
  BLOG: {
    title: 'Promo Blog | Influencer Marketing Insights & Trends',
    description: 'Expert insights on influencer marketing, content creator strategies, native language campaign optimization, and authentic brand collaborations.',
    keywords: [
      'influencer marketing blog',
      'creator tips',
      'brand sponsorships guide',
      'niche audience reach',
      'Promo blog',
    ],
    openGraph: {
      type: 'website' as const,
    },
  },
  ABOUT: {
    title: 'About Promo | Premium Influencer Marketing Marketplace',
    description: 'Learn about Promo\'s mission to simplify creator-brand collaborations with direct campaigns, native language matching, and verified performance metrics.',
    keywords: [
      'about Promo',
      'influencer platform mission',
      'creator marketplace history',
      'brand matchmaking platform',
    ],
    openGraph: {
      type: 'website' as const,
    },
  },
  CONTACT: {
    title: 'Contact Promo | Support & Inquiries',
    description: 'Reach out to the Promo team for brand collaborations, creator verification support, or general platform inquiries.',
    keywords: [
      'contact Promo',
      'influencer marketing support',
      'brand inquiries',
      'creator help desk',
    ],
    openGraph: {
      type: 'website' as const,
    },
  },
};

// Dynamic metadata generation for blog posts
export function generateBlogMetadata(post: {
  title: string;
  description: string;
  keywords?: string[];
  publishDate?: string;
  modifiedDate?: string;
  author?: string;
  category?: string;
  slug: string;
  image?: string;
}): Metadata {
  const canonicalUrl = `${BASE_URL}/blog/${post.slug}`;
  
  return generateMetadata({
    title: post.title,
    description: post.description,
    keywords: post.keywords,
    canonical: canonicalUrl,
    openGraph: {
      title: post.title,
      description: post.description,
      url: canonicalUrl,
      type: 'article',
      images: post.image ? [{
        url: post.image.startsWith('http') ? post.image : `${BASE_URL}${post.image}`,
        width: 1200,
        height: 630,
        alt: post.title,
      }] : undefined,
    },
    twitter: {
      title: post.title,
      description: post.description,
      images: post.image ? [post.image.startsWith('http') ? post.image : `${BASE_URL}${post.image}`] : undefined,
    },
    jsonLd: [
      {
        '@context': 'https://schema.org',
        '@type': 'BlogPosting',
        headline: post.title,
        description: post.description,
        image: post.image ? (post.image.startsWith('http') ? post.image : `${BASE_URL}${post.image}`) : `${BASE_URL}/og-image.svg`,
        url: canonicalUrl,
        datePublished: post.publishDate,
        dateModified: post.modifiedDate || post.publishDate,
        author: {
          '@type': 'Organization',
          name: post.author || 'Promo Team',
          url: BASE_URL,
        },
        publisher: {
          '@type': 'Organization',
          name: 'Promo',
          logo: {
            '@type': 'ImageObject',
            url: `${BASE_URL}/ion_print.png`,
          },
        },
        mainEntityOfPage: {
          '@type': 'WebPage',
          '@id': canonicalUrl,
        },
        keywords: post.keywords?.join(', ') || '',
        articleSection: post.category,
        inLanguage: 'en-IN',
      },
    ],
  });
}

// Location-based metadata
export function generateLocationMetadata(city: string, state: string = 'India'): Metadata {
  const canonicalUrl = `${BASE_URL}/${city.toLowerCase().replace(/\s+/g, '-')}`;
  
  return generateMetadata({
    title: `Xerox Shop in ${city} | Print Documents Online | Promo`,
    description: `Find the best xerox shops in ${city} with Promo. Upload documents online and print securely at local shops. Privacy-first printing service in ${city}, ${state}.`,
    keywords: [
      `xerox shop ${city}`,
      `xerox near me ${city}`,
      `printing service ${city}`,
      `document printing ${city}`,
      `photocopy shop ${city}`,
      `online printing ${city}`,
      `Promo ${city}`,
    ],
    canonical: canonicalUrl,
    openGraph: {
      title: `Xerox Shop in ${city} | Print Documents Online | Promo`,
      description: `Find the best xerox shops in ${city} with Promo. Upload documents online and print securely at local shops.`,
      url: canonicalUrl,
    },
    jsonLd: [
      {
        '@context': 'https://schema.org',
        '@type': 'LocalBusiness',
        name: `Promo ${city}`,
        description: `Secure document printing service in ${city}, ${state}`,
        url: canonicalUrl,
        address: {
          '@type': 'PostalAddress',
          addressLocality: city,
          addressCountry: 'IN',
        },
        geo: {
          '@type': 'GeoCircle',
          geoMidpoint: {
            '@type': 'GeoCoordinates',
            addressCountry: 'IN',
            addressLocality: city,
          },
          geoRadius: '50000',
        },
        areaServed: {
          '@type': 'City',
          name: city,
        },
      },
    ],
  });
}
