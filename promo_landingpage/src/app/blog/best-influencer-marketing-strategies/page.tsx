"use client";

import { motion } from "framer-motion";
import { SiteHeader } from "@/components/layout/site-header";
import { SiteFooter } from "@/components/layout/site-footer";
import { 
  ArrowLeft, 
  Share2, 
  Bookmark, 
  User,
  ShieldCheck,
  TrendingUp,
  Clock,
  Zap,
  Globe
} from "lucide-react";
import { useRouter } from "next/navigation";

export default function BlogPost() {
  const router = useRouter();

  const post = {
    title: "Best Influencer Marketing Strategies in India 2026: Vetted Campaign Execution Guide",
    author: "Promo Campaign Analysis Team",
    role: "Influencer Marketing Experts",
    date: "June 25, 2026",
    readTime: "12 min",
    category: "Campaign Strategy",
    content: [
      { type: "p", text: "India's creator economy has reached an unprecedented scale in 2026, evolving into a ₹18,000 crore market. Brands are moving away from surface-level metrics like follower count, shifting their focus toward verified engagement and niche authenticity. But how can modern brands design an influencer campaign that guarantees high conversions and real brand loyalty? After analyzing 1,000+ campaigns, we outline the definitive execution guide." },
      
      { type: "h2", text: "1. The Regional Power Shift: Vernacular Reach" },
      { type: "p", text: "One of the most prominent shifts in 2026 is the growth of regional language influence. Audiences in Tier-2 and Tier-3 cities engage far more deeply with creators who converse in their native tongues. Campaigns leveraging regional languages (such as Hindi, Telugu, Tamil, or Bengali) yield up to 4x higher CTR compared to English-only campaigns." },
      
      { type: "h3", text: "Key Statistics on Vernacular Commerce" },
      { type: "ul", items: [
        "📈 **Regional Influence**: 72% of Indian internet users prefer content in their native language.",
        "💬 **Engagement Boost**: Native language campaigns experience a 35% increase in message replies and brand interaction.",
        "🛍️ **Tier-2 Conversion**: Creators speaking regional languages drive 60% higher referral sales in non-metropolitan areas."
      ]},
      
      { type: "h2", text: "2. The Creator Tier Allocation Formula" },
      { type: "p", text: "Achieving balanced campaign performance requires allocating your budget across different creator tiers. A common pitfall is overspending on a single celebrity creator. Instead, successful campaigns implement a diversified allocation:" },
      
      { type: "ul", items: [
        "🥇 **Mega/Celeb Creators (10% Budget)**: Used strictly for top-of-funnel reach, brand awareness, and initial buzz.",
        "🥈 **Mid-Tier Creators (30% Budget)**: Provides steady authority, product demonstrations, and educational value.",
        "🥉 **Micro/Nano Creators (60% Budget)**: Drives grassroots authenticity, high trust, and direct conversions/sales."
      ]},
      
      { type: "h2", text: "3. Crafting Vetted & Clear Campaign Deliverables" },
      { type: "p", text: "Vague creative briefs lead to mismatched campaign outcomes. Using platform tools like Promo Campaign Cards, brands can set exact requirements (e.g., target language, video format, niche tags, mandatory tags) before a creator ever applies. This eliminates back-and-forth negotiations and aligns expectations from day one." }
    ]
  };

  return (
    <div className="min-h-screen bg-white">
      <SiteHeader />
      
      <main className="pt-32 pb-16">
        <article className="max-w-[1280px] mx-auto px-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-16 items-start">
            
            <aside className="hidden lg:block lg:col-span-3 sticky top-32">
              <div className="space-y-10">
                 <button 
                  onClick={() => router.push('/blog')}
                  className="flex items-center gap-3 text-[10px] font-black text-[#94A3B8] hover:text-black uppercase tracking-[0.3em] transition-all group"
                 >
                   <ArrowLeft className="w-3.5 h-3.5 group-hover:-translate-x-1 transition-transform" /> Back to Registry
                 </button>

                 <div className="space-y-8">
                    <div className="flex flex-col gap-2">
                       <span className="text-[10px] font-black text-[#94A3B8] uppercase tracking-[0.3em]">Written By</span>
                       <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-xl bg-[#FB432C] flex items-center justify-center">
                             <TrendingUp className="w-5 h-5 text-white" />
                          </div>
                          <div className="text-left">
                             <div className="font-bold text-black text-xs tracking-tight">{post.author}</div>
                             <div className="text-[10px] font-black text-[#64748B] uppercase tracking-tighter">{post.role}</div>
                          </div>
                       </div>
                    </div>

                    <div className="flex flex-col gap-4 pt-8 border-t border-[#E2E8F0]">
                       <div className="flex items-center justify-between">
                          <span className="text-[10px] font-black text-[#94A3B8] uppercase tracking-[0.3em]">Published</span>
                          <span className="text-xs font-bold text-black mt-1 uppercase tracking-tight">{post.date}</span>
                       </div>
                       <div className="flex items-center justify-between">
                          <span className="text-[10px] font-black text-[#94A3B8] uppercase tracking-[0.3em]">Read Time</span>
                          <span className="text-xs font-bold text-black uppercase tracking-tight">{post.readTime}</span>
                       </div>
                    </div>

                    <div className="flex items-center gap-2 pt-4">
                       <button className="w-9 h-9 rounded-lg border border-[#E2E8F0] flex items-center justify-center hover:bg-black hover:text-white transition-all text-[#64748B]">
                          <Share2 className="w-3.5 h-3.5" />
                       </button>
                       <button className="w-9 h-9 rounded-lg border border-[#E2E8F0] flex items-center justify-center hover:bg-black hover:text-white transition-all text-[#64748B]">
                          <Bookmark className="w-3.5 h-3.5" />
                       </button>
                    </div>
                 </div>

                 <div className="p-6 bg-[#FB432C]/5 rounded-xl border border-[#FB432C]/10 space-y-4">
                    <div className="w-10 h-10 rounded-lg bg-[#FB432C] border border-[#FB432C] flex items-center justify-center shadow-sm">
                       <Globe className="w-5 h-5 text-white" />
                    </div>
                    <p className="text-[11px] text-[#FB432C] font-black uppercase tracking-tight leading-relaxed text-left">
                       PROMO PLATFORM: Match with vetted creators using regional language filters instantly.
                    </p>
                 </div>
              </div>
            </aside>

            <div className="lg:col-span-9 max-w-3xl">
              <div className="space-y-12 text-left">
                <div className="space-y-6">
                   <div className="inline-flex items-center gap-2 px-3 py-1 bg-[#FB432C]/10 rounded-md border border-[#FB432C]/20">
                      <TrendingUp className="w-3.5 h-3.5 text-[#FB432C]" />
                      <span className="text-[10px] font-black tracking-[0.2em] text-[#FB432C] uppercase">{post.category}</span>
                   </div>
                   <h1 className="text-4xl lg:text-6xl font-bold text-black tracking-tighter leading-[0.95] uppercase">
                      {post.title}
                   </h1>
                </div>

                <div className="prose prose-slate max-w-none space-y-10">
                  {post.content.map((item, i) => {
                    if (item.type === "p") return <p key={i} className="text-lg text-[#475569] font-medium leading-[1.6]">{item.text}</p>;
                    if (item.type === "h2") return <h2 key={i} className="text-2xl font-bold text-black tracking-tight pt-8 uppercase">{item.text}</h2>;
                    if (item.type === "h3") return <h3 key={i} className="text-xl font-bold text-black tracking-tight pt-4 uppercase">{item.text}</h3>;
                    if (item.type === "ul" && item.items) return (
                      <ul key={i} className="list-disc pl-6 space-y-2 text-[#475569] font-medium text-lg leading-[1.6]">
                        {item.items.map((li, idx) => <li key={idx} dangerouslySetInnerHTML={{ __html: li }} />)}
                      </ul>
                    );
                    return null;
                  })}
                </div>

                <div className="mt-20 p-8 bg-[#FB432C]/5 rounded-xl border border-[#FB432C]/10 relative overflow-hidden group">
                    <div className="relative z-10 flex flex-col md:flex-row items-center gap-8">
                       <div className="w-14 h-14 shrink-0 rounded-lg bg-[#FB432C] border border-[#FB432C] flex items-center justify-center shadow-xl group-hover:scale-110 transition-transform">
                          <ShieldCheck className="w-8 h-8 text-white" />
                       </div>
                       <div className="space-y-3 text-left flex-1">
                          <h4 className="text-xl font-bold text-black tracking-tight leading-none uppercase">READY TO LAUNCH YOUR CAMPAIGN?</h4>
                          <p className="text-[13px] text-[#475569] font-medium leading-relaxed">Match with verified creators, set exact language targets, and manage payments safely in one dashboard.</p>
                          <button 
                            onClick={() => router.push('/')}
                            className="mt-4 px-6 py-3 bg-black hover:bg-[#FB432C] text-white font-black text-[10px] uppercase tracking-widest rounded-md transition-all active:scale-95"
                          >
                             OPEN APP PORTAL
                          </button>
                       </div>
                    </div>
                 </div>

              </div>
            </div>

          </div>
        </article>
      </main>

      <SiteFooter />
    </div>
  );
}
