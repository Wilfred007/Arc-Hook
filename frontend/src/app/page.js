'use client'

import { useState, useEffect } from 'react'
import Navbar from "@/components/Navbar";
import PrivateSwap from "@/components/PrivateSwap";
import ProofMonitor from "@/components/ProofMonitor";
import MarketOverview from "@/components/MarketOverview";
import AdminPanel from "@/components/AdminPanel";
import Hero from "@/components/Hero";
import { AnimatePresence, motion } from "framer-motion";

export default function Home() {
  const [showApp, setShowApp] = useState(false)
  const [mounted, setMounted] = useState(false)

  useEffect(() => setMounted(true), [])

  if (!mounted) return null

  return (
    <main className="min-h-screen relative overflow-x-hidden">
      <Navbar />
      
      <AnimatePresence mode="wait">
        {!showApp ? (
          <motion.div
            key="landing"
            exit={{ opacity: 0, y: -20 }}
            transition={{ duration: 0.5 }}
          >
            <Hero onLaunch={() => setShowApp(true)} />
          </motion.div>
        ) : (
          <motion.div
            key="app"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="max-w-7xl mx-auto px-4 py-12 lg:py-20 relative"
          >
            {/* Background Decorative Blobs */}
            <div className="absolute top-20 left-1/2 -translate-x-1/2 w-[800px] h-[600px] bg-blue-600/5 blur-[120px] rounded-full -z-10" />
            <div className="absolute bottom-0 right-0 w-[400px] h-[400px] bg-purple-600/5 blur-[100px] rounded-full -z-10" />

            <div className="flex flex-col lg:flex-row gap-8 items-start relative z-10">
              <div className="flex-1 w-full space-y-12">
                <div>
                  <h1 className="text-4xl lg:text-5xl font-bold tracking-tight mb-4">
                    Institutional <br />
                    <span className="text-transparent bg-clip-text bg-linear-to-r from-blue-400 to-cyan-300">
                      Private Execution
                    </span>
                  </h1>
                  <p className="text-slate-400 max-w-lg leading-relaxed">
                    Arc-Hook leverages KZG commitments and the Reactive Network to enable whitelisted institutional traders to execute swaps on Uniswap v4 without revealing their address on-chain.
                  </p>
                </div>

                <MarketOverview />
                
                {/* Admin Panel (Only visible to owner) */}
                <AdminPanel />
              </div>

              <div className="flex flex-col md:flex-row lg:flex-col gap-6 w-full lg:w-auto items-start">
                <PrivateSwap />
                <ProofMonitor />
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Footer / Badge Branding */}
      <footer className="mt-20 border-t border-white/5 py-12">
        <div className="max-w-7xl mx-auto px-4 flex flex-col md:flex-row justify-between items-center gap-8">
           <div className="text-slate-500 text-xs">
             © 2026 Arc-Hook Protocol. All Rights Reserved. Built for privacy-first compliance.
           </div>
           <div className="flex gap-8 items-center grayscale opacity-50 hover:grayscale-0 hover:opacity-100 transition-all">
             <div className="flex items-center gap-1.5 grayscale">
                <div className="w-5 h-5 bg-white rounded-full flex items-center justify-center text-[8px] text-black font-black">U</div>
                <span className="text-[10px] font-bold text-white tracking-widest uppercase">Uniswap v4</span>
             </div>
             <div className="flex items-center gap-1.5">
                <div className="w-5 h-5 bg-white rounded-full flex items-center justify-center text-[10px] text-black font-black">R</div>
                <span className="text-[10px] font-bold text-white tracking-widest uppercase">Reactive Net</span>
             </div>
           </div>
        </div>
      </footer>
    </main>
  );
}
