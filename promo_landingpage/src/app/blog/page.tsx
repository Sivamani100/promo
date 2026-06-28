"use client";

import { motion } from "framer-motion";
import { SiteHeader } from "@/components/layout/site-header";
import { SiteFooter } from "@/components/layout/site-footer";
import { 
  Newspaper, 
  Search, 
  ArrowRight, 
  Clock, 
  TrendingUp,
  ShieldCheck,
  Zap,
  Users
} from "lucide-react";
import { useState } from "react";
import { cn } from "@/lib/utils";

const mockPosts = [
  {
    title: "Best Influencer Marketing Strategies in India 2026: Vetted Campaign Execution Guide",
    excerpt: "Discover the top influencer marketing strategies for 2026. Compare regional targeting, creator tier allocations, budget optimization, and how to scale campaigns to reach millions.",
    author: "Promo Campaign Analysis Team",
    date: "June 25, 2026",
    readTime: "12 min",
    tag: "Campaign Strategy",
    icon: TrendingUp,
    slug: "best-influencer-marketing-strategies"
  },
  {
    title: "How to Find Niche Creators for Regional & Language-Targeted Campaigns",
    excerpt: "Niche creators with local language fluency deliver up to 4x higher engagement. Learn how to locate, vet, and collaborate with creators who speak your target audience's language.",
    author: "Promo Localization Team",
    date: "June 20, 2026",
    readTime: "10 min",
    tag: "Creator Discovery",
    icon: Users,
    slug: "how-to-find-niche-creators"
  },
  {
    title: "Micro-Influencers vs Mega-Influencers: ROI Analysis for Modern Consumer Brands",
    excerpt: "Detailed ROI analysis comparing micro-influencers and celebrity creators. Discover why authentic micro-influencers are yielding higher conversions, better cost per acquisition, and lower bounce rates.",
    author: "Promo ROI Analytics Group",
    date: "June 15, 2026",
    readTime: "8 min",
    tag: "ROI Analysis",
    icon: Zap,
    slug: "roi-micro-influencers"
  },
  {
    title: "Brand Safety in Creator Marketing: A Guide to Vetted Collaborations and Secure Handshakes",
    excerpt: "Protect your brand safety online. This guide covers setting transparent campaign requirements, contract templates, payment security, and verifying organic creator reach.",
    author: "Promo Brand Safety Lab",
    date: "June 10, 2026",
    readTime: "9 min",
    tag: "Brand Safety",
    icon: ShieldCheck,
    slug: "campaign-safety-guidelines"
  }
];

export default function Blog() {
  const [activeTag, setActiveTag] = useState("All");
  const [searchQuery, setSearchQuery] = useState("");

  const filteredPosts = mockPosts.filter(p => {
    const matchesTag = activeTag === "All" || p.tag === activeTag;
    const matchesSearch = p.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
                          p.excerpt.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesTag && matchesSearch;
  });

  const featuredPost = mockPosts[0];
  const gridPosts = filteredPosts.filter(p => p.slug !== featuredPost.slug || activeTag !== "All" || searchQuery !== "");

  return (
    <div className="min-h-screen bg-[#FDFDFD] flex flex-col font-sans selection:bg-[#FB432C] selection:text-white overflow-x-hidden">
      <SiteHeader />
      
      <main className="flex-1 pt-32 pb-0">
        
        {/* Blog Hero */}
        <section className="relative pt-12 pb-16 text-center">
          <div className="absolute inset-0 z-0 opacity-[0.03] pointer-events-none" 
               style={{ backgroundImage: 'radial-gradient(#000 1.5px, transparent 0)', backgroundSize: '40px 40px' }} />
               
          <div className="max-w-[1280px] mx-auto px-6 relative z-10">
             <motion.div 
               variants={{
                 hidden: { opacity: 0, y: 20 },
                 visible: { opacity: 1, y: 0, transition: { duration: 0.6 } }
               }}
               initial="hidden"
               animate="visible"
               className="max-w-4xl mx-auto"
             >
               <div className="inline-flex items-center gap-2.5 px-4 h-8 rounded-full bg-black/5 border border-black/5 mb-8">
                 <Newspaper className="w-3.5 h-3.5 text-black" />
                 <span className="text-[10px] font-bold text-black uppercase tracking-[0.2em] leading-none">Creator Hub</span>
               </div>
               
               <h1 className="text-[50px] md:text-[80px] font-extrabold tracking-tighter text-black leading-[0.95] mb-6 uppercase">
                 The Promo <br /> Insights Blog.
               </h1>
               <p className="text-lg md:text-xl font-medium text-gray-500 leading-relaxed italic max-w-2xl mx-auto">
                 Expert insights on influencer marketing, content creator strategies, language-targeted campaigns, and authentic brand collaborations. Discover how Promo is driving creator commerce.
               </p>
             </motion.div>
          </div>
        </section>

        {/* Sticky Category Filter */}
        <section className="sticky top-[100px] z-[40] py-4 bg-white/80 backdrop-blur-xl border-y border-gray-100">
           <div className="max-w-[1280px] mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-6">
              <div className="flex items-center gap-2 overflow-x-auto pb-2 md:pb-0 no-scrollbar w-full md:w-auto">
                 {["All", "Campaign Strategy", "Creator Discovery", "ROI Analysis", "Brand Safety"].map(tag => (
                    <button 
                      key={tag}
                      onClick={() => setActiveTag(tag)}
                      className={cn(
                        "h-10 px-6 rounded-full font-bold text-[11px] uppercase tracking-widest transition-all whitespace-nowrap border",
                        activeTag === tag 
                          ? "bg-black text-white border-black shadow-lg shadow-black/10" 
                          : "bg-gray-50 text-gray-500 border-gray-200 hover:border-black/20 hover:bg-white"
                      )}
                    >
                       {tag}
                    </button>
                 ))}
              </div>
              <div className="relative w-full md:w-[280px]">
                 <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                 <input 
                   type="text" 
                   value={searchQuery}
                   onChange={(e) => setSearchQuery(e.target.value)}
                   placeholder="Search articles..." 
                   className="w-full h-10 bg-gray-50 border border-gray-200 rounded-full pl-11 pr-4 text-[13px] font-medium placeholder:text-gray-400 focus:border-black focus:ring-1 focus:ring-black outline-none transition-all" 
                 />
              </div>
           </div>
        </section>

        {/* Featured Post (Only show if no search/filter active or if matching) */}
        {activeTag === "All" && searchQuery === "" && (
          <section className="py-16 relative z-20">
             <div className="max-w-[1280px] mx-auto px-6">
                <motion.div 
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.8 }}
                  className="group relative bg-black rounded-[40px] overflow-hidden shadow-2xl shadow-black/20 p-10 md:p-16 flex flex-col justify-end min-h-[420px] cursor-pointer border border-black/20"
                  onClick={() => window.location.href = `/landingpage/blog/${featuredPost.slug}`}
                >
                   {/* Background decoration */}
                   <div className="absolute top-0 right-0 w-[500px] h-[500px] bg-[#FB432C]/10 opacity-30 blur-[120px] rounded-full group-hover:scale-110 transition-transform duration-1000 pointer-events-none" />
                   <div className="absolute inset-0 bg-gradient-to-t from-black via-black/60 to-transparent z-10" />
                   
                   <div className="relative z-20 space-y-6 max-w-3xl text-left">
                      <div className="flex items-center gap-4">
                         <span className="px-4 py-1.5 bg-[#FB432C] text-white rounded-full text-[11px] font-black uppercase tracking-widest">
                            Featured
                         </span>
                         <div className="flex items-center gap-2 text-white/40 text-[10px] font-bold uppercase tracking-widest">
                            <TrendingUp className="w-3.5 h-3.5 text-brand-primary" /> Top Read
                         </div>
                      </div>
                      
                      <h2 className="text-3xl md:text-5xl font-extrabold text-white tracking-tighter leading-[0.95] uppercase group-hover:text-[#FB432C] transition-colors">
                         {featuredPost.title}
                      </h2>
                      <p className="text-lg text-gray-400 font-medium leading-relaxed max-w-2xl">
                         {featuredPost.excerpt}
                      </p>
                      
                      <div className="flex flex-wrap items-center gap-6 pt-2">
                         <div className="flex items-center gap-2">
                            <div className="w-8 h-8 rounded-full bg-white/10 border border-white/20 flex items-center justify-center text-[10px] font-black text-white">
                               PR
                            </div>
                            <span className="text-white font-bold text-xs">{featuredPost.author}</span>
                         </div>
                         <div className="flex items-center gap-2 text-gray-500 text-[10px] font-bold uppercase tracking-widest">
                            <Clock className="w-3.5 h-3.5" /> {featuredPost.readTime} read
                         </div>
                         <span className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">{featuredPost.date}</span>
                      </div>
                   </div>
                </motion.div>
             </div>
          </section>
        )}

        {/* Post Grid */}
        <section className="py-24 bg-[#F8FAFC] border-y border-gray-100">
           <div className="max-w-[1280px] mx-auto px-6">
              {filteredPosts.length === 0 ? (
                <div className="text-center py-20">
                  <p className="text-lg font-medium text-gray-400">No articles matched your search.</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                   {gridPosts.map((post, i) => (
                      <motion.div
                         key={post.slug}
                         initial={{ opacity: 0, y: 30 }}
                         whileInView={{ opacity: 1, y: 0 }}
                         viewport={{ once: true }}
                         transition={{ delay: i * 0.1, duration: 0.6 }}
                         className="group bg-white p-8 rounded-[32px] border border-gray-200 hover:border-black/10 hover:shadow-2xl hover:shadow-black/5 hover:-translate-y-2 transition-all duration-500 cursor-pointer flex flex-col justify-between h-full"
                         onClick={() => window.location.href = `/landingpage/blog/${post.slug}`}
                      >
                         <div>
                            <div className="flex items-center justify-between mb-8">
                               <div className="w-14 h-14 rounded-2xl bg-gray-50 border border-gray-100 flex items-center justify-center text-black group-hover:bg-[#FB432C] group-hover:text-white transition-all duration-500 shadow-sm">
                                  <post.icon className="w-6 h-6" />
                               </div>
                               <span className="px-3 py-1.5 bg-gray-50 border border-gray-100 text-[10px] font-black text-gray-500 uppercase tracking-widest rounded-full">
                                  {post.tag}
                               </span>
                            </div>
                            
                            <h3 className="text-xl lg:text-2xl font-black text-black tracking-tighter uppercase leading-tight mb-4 group-hover:text-[#FB432C] transition-colors">
                               {post.title}
                            </h3>
                            <p className="text-[14px] font-medium text-gray-500 leading-relaxed line-clamp-3">
                               {post.excerpt}
                            </p>
                         </div>

                         <div className="mt-8 pt-6 border-t border-gray-100 flex items-center justify-between">
                            <div className="space-y-1 text-left">
                               <span className="text-[11px] font-bold text-gray-800 block">{post.author}</span>
                               <div className="flex items-center gap-3 text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                                  <span>{post.date}</span>
                                  <span className="flex items-center gap-1"><Clock className="w-3 h-3" /> {post.readTime}</span>
                                </div>
                            </div>
                            <div className="w-10 h-10 rounded-full bg-gray-50 group-hover:bg-[#FB432C] border border-gray-100 group-hover:border-transparent flex items-center justify-center text-black group-hover:text-white transition-all duration-500 shrink-0 shadow-sm">
                               <ArrowRight className="w-4 h-4" />
                            </div>
                         </div>
                      </motion.div>
                   ))}
                </div>
              )}
           </div>
        </section>

        {/* Subscribe CTA */}
        <section className="py-32 bg-white text-center">
           <div className="max-w-2xl mx-auto px-6">
              <Newspaper className="w-12 h-12 text-[#FB432C] mx-auto mb-6 opacity-20" />
              <h2 className="text-3xl md:text-5xl font-extrabold text-black tracking-tighter uppercase mb-6">Stay Connected. <br /> Drive Influence.</h2>
              <p className="text-lg text-gray-500 font-medium mb-10 italic">
                 Join modern brands and creators receiving weekly industry digests, sponsorship tips, and campaign playbooks.
              </p>
              
              <form className="flex flex-col sm:flex-row gap-4 max-w-md mx-auto">
                 <input 
                    type="email" 
                    placeholder="Enter your email address" 
                    className="flex-1 h-14 bg-gray-50 border border-gray-200 rounded-full px-6 focus:outline-none focus:border-black focus:ring-1 focus:ring-black transition-all text-sm font-semibold" 
                    required 
                 />
                 <button 
                    type="submit"
                    className="h-14 px-8 bg-black hover:bg-[#FB432C] text-white font-bold text-[12px] uppercase tracking-widest rounded-full transition-all duration-300 shadow-xl shadow-black/10"
                 >
                    Subscribe
                 </button>
              </form>
           </div>
        </section>

      </main>

      <SiteFooter />
    </div>
  );
}
