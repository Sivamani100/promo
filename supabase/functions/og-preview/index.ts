import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * OG Preview Edge Function
 *
 * Returns an HTML page with Open Graph meta tags for Promo entities.
 * When a link like https://promo.app/card/xxx is shared to WhatsApp,
 * iMessage, Telegram, or Twitter, this function provides the rich
 * preview card with title, description, and image.
 *
 * Routes:
 *   GET /og-preview?type=card&id=xxx
 *   GET /og-preview?type=influencer&id=xxx
 *   GET /og-preview?type=brand&id=xxx
 */
serve(async (req: Request) => {
  const url = new URL(req.url);
  const type = url.searchParams.get('type');
  const id = url.searchParams.get('id');

  if (!type || !id) {
    return new Response('Missing type or id parameter', { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  let title = 'Promo — Connect Brands & Creators';
  let description = 'The platform connecting brands with influencers for collaborations.';
  let image = 'https://promo.app/og-default.png';
  let pageUrl = `https://promo.app/${type}/${id}`;

  try {
    if (type === 'card') {
      const { data } = await supabase
        .from('cards')
        .select('title, budget, category, brand_id, cover_image, profiles!cards_brand_id_fkey(display_name)')
        .eq('id', id)
        .single();

      if (data) {
        title = `${data.title} — Promo`;
        const brandName = data.profiles?.display_name ?? 'Brand';
        const budgetText = data.budget ? `${data.budget}` : 'Flexible';
        description = `${budgetText} • ${data.category ?? 'Collaboration'} • ${brandName}`;
        if (data.cover_image) image = data.cover_image;
      }
    } else if (type === 'influencer') {
      const { data } = await supabase
        .from('profiles')
        .select('display_name, bio, avatar_url, niche, platforms')
        .eq('id', id)
        .single();

      if (data) {
        title = `${data.display_name} — Influencer on Promo`;
        const niche = data.niche ?? 'Creator';
        // Sum follower counts across platforms
        let totalFollowers = 0;
        if (data.platforms && Array.isArray(data.platforms)) {
          for (const p of data.platforms) {
            totalFollowers += (p.followers || 0);
          }
        }
        const followersText = totalFollowers > 0
          ? `${(totalFollowers / 1000).toFixed(0)}K followers`
          : '';
        description = `${niche} creator${followersText ? ` • ${followersText} across platforms` : ''}`;
        if (data.avatar_url) image = data.avatar_url;
      }
    } else if (type === 'brand') {
      const { data } = await supabase
        .from('profiles')
        .select('display_name, bio, avatar_url')
        .eq('id', id)
        .single();

      if (data) {
        title = `${data.display_name} — Brand on Promo`;
        description = data.bio || 'Discover collaboration opportunities with this brand on Promo.';
        if (data.avatar_url) image = data.avatar_url;
      }
    }
  } catch (e) {
    console.error('OG Preview fetch error:', e);
  }

  // Return HTML page with OG meta tags
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)}</title>

  <!-- Open Graph -->
  <meta property="og:type" content="website" />
  <meta property="og:title" content="${escapeHtml(title)}" />
  <meta property="og:description" content="${escapeHtml(description)}" />
  <meta property="og:image" content="${escapeHtml(image)}" />
  <meta property="og:url" content="${escapeHtml(pageUrl)}" />
  <meta property="og:site_name" content="Promo" />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapeHtml(title)}" />
  <meta name="twitter:description" content="${escapeHtml(description)}" />
  <meta name="twitter:image" content="${escapeHtml(image)}" />

  <!-- Redirect to app or store -->
  <meta http-equiv="refresh" content="0; url=${escapeHtml(pageUrl)}" />
</head>
<body>
  <p>Redirecting to Promo...</p>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
});

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
