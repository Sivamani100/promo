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
  Clock,
  Globe
} from "lucide-react";
import { useRouter } from "next/navigation";

export default function BlogPost() {
  const router = useRouter();

  const post = {
    title: "Brand Safety in Creator Marketing: A Guide to Vetted Collaborations and Secure Handshakes",
    author: "Promo Brand Safety Lab",
    role: "Safety & Compliance Officers",
    date: "June 10, 2026",
    readTime: "9 min",
    category: "Brand Safety",
    content: [
      { type: "p", text: "As influencer campaigns become core to business strategies, security, fraud prevention, and brand safety have emerged as top concerns. With the market flooded by manipulated statistics, artificial engagement, and inconsistent contract deliverables, how can brands safeguard their marketing investments? Here is our safety guide." },
      
      { type: "h2", text: "1. The Risk of Unvetted Partnerships" },
      { type: "p", text: "Traditional influencer deals often occur through DMs or messaging apps. This introduces massive security and operational vulnerabilities: creators falsifying performance screenshots, brands withholding payments after deliverables are met, and lack of clear legal contracts. The result is a high dispute rate and wasted marketing budgets." },
      
      { type: "h2", text: "2. The Promo Verification Framework" },
      { type: "p", text: "At Promo, we build trust into the platform infrastructure. Creators are required to verify their social accounts and submit direct performance data to obtain verification badges. This ensures that when a brand hires a creator, they are paying for real, organic, and targeted reach rather than inflated bot metrics." },
      
      { type: "h3", text: "Key Safety Protocols on Promo" },
      { type: "ul", items: [
        "🛡️ **Vetted Creator Profiles**: All creators are authenticated to ensure metrics are organic and valid.",
        "🤝 **Secure Milestones**: Contracts are mapped dynamically into milestone agreements before work begins.",
        "💬 **Encrypted Communications**: Chats and campaign communications are secured with Supabase Row-Level Security.",
        "📊 **Verified Performance**: Reach, clicks, and language targets are logged and verified upon campaign completion."
      ]},
      
      { type: "h2", text: "3. Establishing Safe Milestone Agreements" },
      { type: "p", text: "Never send 100% upfront payment before content is reviewed. Implement a secure milestone handshake: 1) Creator accepts the campaign card; 2) Creator submits the draft for brand approval; 3) Content goes live; 4) Balance is released automatically. This protects both the creator's effort and the brand's capital." }
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
                             <ShieldCheck className="w-5 h-5 text-white" />
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
                       BRAND SAFETY: Establish secure milestone agreements and hire verified creators on Promo.
                    </p>
                 </div>
              </div>
            </aside>

            <div className="lg:col-span-9 max-w-3xl">
              <div className="space-y-12 text-left">
                <div className="space-y-6">
                   <div className="inline-flex items-center gap-2 px-3 py-1 bg-[#FB432C]/10 rounded-md border border-[#FB432C]/20">
                      <ShieldCheck className="w-3.5 h-3.5 text-[#FB432C]" />
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
                          <h4 className="text-xl font-bold text-black tracking-tight leading-none uppercase">HIRE WITH TOTAL CONFIDENCE</h4>
                          <p className="text-[13px] text-[#475569] font-medium leading-relaxed">Protect your campaign budget using Promo's verified milestone agreements and direct tracking.</p>
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
