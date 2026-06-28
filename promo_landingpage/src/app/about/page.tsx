"use client";

import { motion } from "framer-motion";
import { SiteHeader } from "@/components/layout/site-header";
import { SiteFooter } from "@/components/layout/site-footer";
import { ShieldCheck, Network } from "lucide-react";

export default function AboutPage() {
  const stats = [
    { label: "Active Creators", value: "5,000+" },
    { label: "Indian Languages", value: "12+" },
    { label: "Campaigns Run", value: "850+" },
    { label: "Verification Rate", value: "100%" }
  ];

  return (
    <div className="min-h-screen bg-white selection:bg-[#FB432C] selection:text-white">
      <SiteHeader />
      
      <main className="pt-32 pb-24">
        <div className="max-w-[1280px] mx-auto px-6">
          
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
            className="max-w-4xl max-w-none"
          >
            <div className="space-y-6 mb-16">
              <div className="inline-flex items-center gap-2 px-3 py-1 bg-black/5 rounded-md border border-black/5">
                <Network className="w-3.5 h-3.5 text-black" />
                <span className="text-[10px] font-black tracking-[0.1em] text-black uppercase">Our Origin</span>
              </div>
              <h1 className="text-5xl md:text-7xl lg:text-[80px] font-bold text-black tracking-tighter leading-[0.95] uppercase">
                Marketing is <br /><span className="text-[#FB432C]">About Connection.</span>
              </h1>
              <p className="text-xl md:text-2xl text-[#64748B] font-medium leading-relaxed max-w-2xl italic mt-6">
                 "We built Promo because no brand should struggle to find authentic local creators who actually speak their customers' language."
              </p>
            </div>

            {/* Mission Statement */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-16 mb-24">
               <div>
                  <h3 className="text-2xl font-bold text-black tracking-tight uppercase mb-4">The Problem</h3>
                  <p className="text-[#64748B] font-medium leading-relaxed">
                     Across India, brands waste lakhs on marketing campaigns with zero ROI because of bot accounts or misaligned audience demographics. Finding local, native-speaking content creators is manual, slow, and expensive, filled with spam DMs and unverified metrics.
                  </p>
               </div>
               <div>
                  <h3 className="text-2xl font-bold text-black tracking-tight uppercase mb-4">Our Promo Solution</h3>
                  <p className="text-[#64748B] font-medium leading-relaxed">
                     We engineered a direct campaign card matchmaking protocol. Brands list campaign requirements including specific target languages (Hindi, Telugu, Tamil). Top verified creators match and collaborate instantly in a clean, secure dashboard.
                  </p>
               </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-24">
               {stats.map((stat, i) => (
                  <motion.div 
                     initial={{ opacity: 0, scale: 0.9 }}
                     whileInView={{ opacity: 1, scale: 1 }}
                     viewport={{ once: true }}
                     transition={{ delay: i * 0.1 }}
                     key={stat.label} 
                     className="bg-[#F8FAFC] border border-[#E2E8F0] p-8 rounded-2xl flex flex-col items-center justify-center text-center group hover:bg-black transition-colors"
                   >
                     <span className="text-4xl lg:text-5xl font-black text-black tracking-tighter group-hover:text-white transition-colors">{stat.value}</span>
                     <span className="text-[11px] font-bold text-[#64748B] uppercase tracking-[0.1em] mt-2 group-hover:text-white/60 transition-colors">{stat.label}</span>
                  </motion.div>
               ))}
            </div>

            {/* Vision Block */}
            <div className="p-10 md:p-16 bg-black rounded-3xl border border-white/5 relative overflow-hidden group">
               <div className="absolute top-0 right-0 w-96 h-96 bg-[#FB432C] opacity-[0.05] blur-[100px] rounded-full" />
               <div className="relative z-10 flex flex-col items-start gap-8">
                  <div className="w-14 h-14 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center">
                     <ShieldCheck className="w-7 h-7 text-[#FB432C]" />
                  </div>
                  <div className="space-y-4 max-w-2xl">
                     <h4 className="text-3xl font-bold text-white tracking-tight uppercase leading-none">Built for Creators, Trusted by Brands.</h4>
                     <p className="text-base text-slate-400 font-medium leading-relaxed italic">
                        "While we started with local language diversity across India, our platform is designed to handle global-scale outreach. Promo is the new standard for authentic influence."
                     </p>
                  </div>
               </div>
            </div>

          </motion.div>
        </div>
      </main>

      <SiteFooter />
    </div>
  );
}

