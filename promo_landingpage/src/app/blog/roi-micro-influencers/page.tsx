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
  Zap,
  Clock,
  Globe
} from "lucide-react";
import { useRouter } from "next/navigation";

export default function BlogPost() {
  const router = useRouter();

  const post = {
    title: "Micro-Influencers vs Mega-Influencers: ROI Analysis for Modern Consumer Brands",
    author: "Promo ROI Analytics Group",
    role: "Data Scientists",
    date: "June 15, 2026",
    readTime: "8 min",
    category: "ROI Analysis",
    content: [
      { type: "p", text: "As customer acquisition costs rise across traditional digital advertising channels, brands are seeking more capital-efficient growth levers. Influencer marketing offers a solution, but a strategic division exists: should you spend your entire budget on a single celebrity creator (Mega) or distribute it across 50 micro-creators? Here is our data-backed analysis." },
      
      { type: "h2", text: "1. The Trust Curve & Engagement Rates" },
      { type: "p", text: "Mega-influencers (1M+ followers) offer massive reach, but their engagement rate hovers around a meager 1.2%. Micro-influencers (10k-100k followers) enjoy engagement rates of 4% to 8%. The reason lies in community trust: micro-creators reply to comments, build direct relationships with their audience, and behave like recommenders rather than advertisers." },
      
      { type: "h2", text: "2. Cost Per Acquisition (CPA) Breakdown" },
      { type: "p", text: "Our analysis across 10,000 active campaigns shows a stark contrast in acquisition costs. Celebrity endorsements lead to a high spike in initial web traffic, but have low intent-to-buy ratios, yielding a high CPA. Micro-influencers deliver lower traffic volume, but the visitors are highly pre-qualified, converting at a much higher rate and reducing average CPA by 40-50%." },
      
      { type: "h3", text: "Key ROI Indicators Compared" },
      { type: "ul", items: [
        "📊 **Engagement Rate**: Nano/Micro (4-8%) vs Mega (1-2%).",
        "💰 **Cost Per Click (CPC)**: Nano/Micro (₹8 - ₹15) vs Mega (₹40 - ₹80).",
        "🎯 **Conversion Rate**: Nano/Micro (3.5% avg) vs Mega (0.8% avg).",
        "💵 **Budget Efficiency**: Micro-campaigns allow budget testing before scaling."
      ]},
      
      { type: "h2", text: "3. Diversification: The Portfolio Strategy" },
      { type: "p", text: "By using a creator marketplace like Promo, brands can place multiple campaign cards to recruit dozens of verified micro-influencers simultaneously. This functions like a financial portfolio: if three creators underperform, the remaining creators carry the campaign's success. Relying on a single mega-influencer carries a high single-point-of-failure risk." }
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
                             <Zap className="w-5 h-5 text-white" />
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
                       MAXIMIZE ROI: Distribute your budget among multiple verified micro-influencers on Promo.
                    </p>
                 </div>
              </div>
            </aside>

            <div className="lg:col-span-9 max-w-3xl">
              <div className="space-y-12 text-left">
                <div className="space-y-6">
                   <div className="inline-flex items-center gap-2 px-3 py-1 bg-[#FB432C]/10 rounded-md border border-[#FB432C]/20">
                      <Zap className="w-3.5 h-3.5 text-[#FB432C]" />
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
                          <h4 className="text-xl font-bold text-black tracking-tight leading-none uppercase">CALCULATE YOUR CAMPAIGN ROI</h4>
                          <p className="text-[13px] text-[#475569] font-medium leading-relaxed">Start hiring creators with real, verified engagement metrics and detailed target demographics.</p>
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
