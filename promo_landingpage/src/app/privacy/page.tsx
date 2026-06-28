"use client";

import { motion } from "framer-motion";
import { SiteHeader } from "@/components/layout/site-header";
import { SiteFooter } from "@/components/layout/site-footer";
import { ShieldCheck, Database, CheckCircle2 } from "lucide-react";

export default function PrivacyPolicy() {
  const sections = [
    { title: "Introduction", content: "Welcome to Promo. We are committed to protecting your personal information and your right to privacy. Promo is an influencer marketing marketplace that connects brands and content creators. This policy outlines how we collect, process, and protect your information." },
    { title: "Information We Collect", content: "We collect information you provide directly to us: account setup credentials (email, name), campaign descriptions, target languages, budget scopes, and communication messages between brands and creators." },
    { title: "Creator Verification", content: "Creators submit social channel metrics and identity verification to secure their trust badges. We only process verification metrics to establish legitimacy and do not share raw document assets with third parties." },
    { title: "Data Storage & Security", content: "All platform data is securely stored inside Supabase databases with strict Row-Level Security (RLS) policies. Communications and briefs are encrypted in transit via TLS 1.3 and stored securely at rest." },
    { title: "Data Deletion Rights", content: "You hold full ownership of your data. If you delete your account or campaigns, all related chats, files, and matched records are permanently purged from our active databases immediately." }
  ];

  return (
    <div className="min-h-screen bg-[#FDFDFD] flex flex-col font-sans selection:bg-[#FB432C] selection:text-white overflow-x-hidden">
      <SiteHeader />
      
      <main className="flex-1 pt-32 pb-0">
        
        {/* Privacy Hero */}
        <section className="relative pt-12 pb-16 text-center border-b border-gray-100">
          <div className="absolute inset-0 z-0 opacity-[0.03] pointer-events-none" 
               style={{ backgroundImage: 'radial-gradient(#000 1.5px, transparent 0)', backgroundSize: '40px 40px' }} />
               
          <div className="max-w-[1280px] mx-auto px-6 relative z-10 flex flex-col items-center">
             <motion.div 
               variants={{
                 hidden: { opacity: 0, y: 20 },
                 visible: { opacity: 1, y: 0, transition: { duration: 0.6 } }
               }}
               initial="hidden"
               animate="visible"
               className="max-w-3xl"
             >
               <div className="inline-flex items-center gap-2.5 px-4 h-8 rounded-full bg-black/5 border border-black/5 mb-8">
                 <ShieldCheck className="w-3.5 h-3.5 text-black" />
                 <span className="text-[10px] font-bold text-black uppercase tracking-[0.2em] leading-none">Security Protocol</span>
               </div>
               
               <h1 className="text-[40px] md:text-[64px] font-extrabold tracking-tighter text-black leading-[0.95] mb-8 uppercase">
                 Privacy Policy
               </h1>
               
               <div className="flex flex-wrap items-center justify-center gap-6 md:gap-12 pt-4">
                  <div className="flex flex-col items-center text-center">
                     <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest leading-none mb-2">LAST REVISION</span>
                     <span className="text-[12px] font-black text-black uppercase tracking-widest bg-gray-100 px-3 py-1 rounded-md font-mono">JUNE 27, 2026</span>
                  </div>
                  <div className="w-[1px] h-8 bg-gray-200 hidden md:block" />
                  <div className="flex flex-col items-center text-center">
                     <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest leading-none mb-2">COMPLIANCE</span>
                     <span className="text-[12px] font-black text-emerald-700 uppercase tracking-widest bg-emerald-50 px-3 py-1 rounded-md">VERIFIED</span>
                  </div>
               </div>
             </motion.div>
          </div>
        </section>

        {/* Policy Content */}
        <section className="py-24 bg-white relative z-20">
           <div className="max-w-[1280px] mx-auto px-6 grid grid-cols-1 lg:grid-cols-12 gap-16 items-start">
             
             {/* Left Sidebar Navigation */}
             <aside className="hidden lg:block lg:col-span-4 sticky top-40">
                <div className="space-y-12 pr-8">
                   <div className="flex flex-col gap-4 border-l-2 border-gray-100 pl-6 relative">
                      <div className="absolute top-0 -left-[1px] w-0.5 h-16 bg-black" />
                      <span className="text-[10px] font-black text-black uppercase tracking-[0.2em] mb-2">Policy Navigation</span>
                      {sections.map((section, i) => (
                        <a 
                          key={section.title} 
                          href={`#section-${i}`}
                          className="text-[12px] font-bold text-gray-400 hover:text-black transition-colors flex items-center justify-between group uppercase tracking-widest py-1"
                        >
                           {section.title}
                           <CheckCircle2 className="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity text-[#FB432C]" />
                        </a>
                      ))}
                   </div>
                   
                   {/* Trust Badge */}
                   <div className="p-8 bg-[#F8FAFC] rounded-[32px] border border-gray-200">
                      <div className="w-12 h-12 rounded-[16px] bg-white border border-gray-100 flex items-center justify-center shadow-sm mb-6">
                         <Database className="w-5 h-5 text-black" />
                      </div>
                      <h4 className="text-sm font-black text-black tracking-tight uppercase mb-3">Data Protection</h4>
                      <p className="text-[13px] text-gray-500 font-medium leading-relaxed italic">
                         "Strict database isolation patterns and Row-Level Security ensuring absolute campaign asset privacy."
                      </p>
                   </div>
                </div>
             </aside>

             {/* Main Policy Body */}
             <div className="lg:col-span-8">
                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  className="space-y-16"
                >
                   <p className="text-xl md:text-2xl text-gray-500 font-medium leading-relaxed mb-16 italic border-l-4 border-black pl-6">
                     "At Promo, we believe that data integrity and transparency are essential for trusted brand and creator relations. We protect your communications."
                   </p>
                   
                   <div className="space-y-16">
                     {sections.map((section, i) => (
                       <motion.section 
                         key={section.title} 
                         id={`section-${i}`} 
                         initial={{ opacity: 0, y: 15 }}
                         whileInView={{ opacity: 1, y: 0 }}
                         viewport={{ once: true }}
                         transition={{ delay: i * 0.05 }}
                         className="scroll-mt-32"
                       >
                         <h3 className="text-xl md:text-3xl font-black text-black tracking-tighter mb-6 uppercase">{section.title}</h3>
                         <p className="text-gray-600 font-medium text-base md:text-lg leading-relaxed">{section.content}</p>
                       </motion.section>
                     ))}
                   </div>
                </motion.div>
             </div>

           </div>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
