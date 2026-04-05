'use client'

import React, { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Cpu, CheckCircle2, Loader2, ExternalLink } from 'lucide-react'
import { useAccount, useReadContract, useWatchContractEvent } from 'wagmi'
import { ADDRESSES, ABIS, NETWORKS } from '@/lib/constants'

export default function ProofMonitor() {
  const { address, isConnected } = useAccount()
  const [step, setStep] = useState(1)
  const [progress, setProgress] = useState(0)
  const [mounted, setMounted] = useState(false)

  // Avoid hydration mismatch
  useEffect(() => setMounted(true), [])

  // Check if address is whitelisted
  const { data: isWhitelisted, refetch } = useReadContract({
    address: ADDRESSES.Registry,
    abi: ABIS.Registry,
    functionName: 'isWhitelisted',
    args: [address],
    chainId: NETWORKS.UnichainSepolia,
    enabled: !!address,
  })

  // Watch for whitelist updates
  useWatchContractEvent({
    address: ADDRESSES.Registry,
    abi: ABIS.Registry,
    eventName: 'WhitelistUpdated',
    chainId: NETWORKS.UnichainSepolia,
    onLogs() {
      refetch()
    },
  })

  // Simulation effect for the demo (speeds up if whitelisted)
  useEffect(() => {
    if (!mounted) return
    const interval = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 100) {
          setStep((s) => (s >= 4 ? 1 : s + 1))
          return 0
        }
        return prev + (isWhitelisted ? 5 : 2)
      })
    }, 100)
    return () => clearInterval(interval)
  }, [mounted, isWhitelisted])

  const steps = [
    { id: 1, name: 'Fetching Inputs', desc: 'Retrieving whitelist data from Unichain Registry' },
    { id: 2, name: 'Generating Witness', desc: 'Creating local cryptographic witness for address' },
    { id: 3, name: 'Computing Proof', desc: 'Generating KZG polynomial opening proof' },
    { id: 4, name: 'Verification', desc: 'Confirming proof validity against global commitment' },
  ]

  if (!mounted) return <div className="glass rounded-2xl p-6 w-full max-w-sm h-[600px] animate-pulse" />

  return (
    <div className="glass rounded-2xl p-6 w-full max-w-sm sticky top-24 h-fit border-white/5">
       <div className="flex items-center gap-2 mb-6">
         <Cpu className="w-5 h-5 text-blue-400" />
         <h2 className="font-bold text-sm uppercase tracking-widest text-slate-300">Privacy Proof Generation</h2>
       </div>

       <div className="relative aspect-square mb-8 rounded-xl overflow-hidden bg-slate-950 border border-white/5 flex items-center justify-center crypto-grid">
          <div className="absolute inset-0 bg-linear-to-t from-blue-600/20 to-transparent pointer-events-none" />
          <motion.div 
            animate={{ 
              rotate: 360,
              scale: isWhitelisted ? [1, 1.2, 1] : [1, 1.1, 1],
            }}
            transition={{ duration: 10, repeat: Infinity, ease: "linear" }}
            className={`w-40 h-40 border border-blue-500/30 rounded-full flex items-center justify-center ${isWhitelisted ? 'shadow-[0_0_20px_rgba(59,130,246,0.3)]' : ''}`}
          >
             <div className="w-32 h-32 border border-blue-400/20 rounded-lg transform rotate-45" />
             <div className="w-32 h-32 border border-blue-400/20 rounded-lg absolute transform -rotate-45" />
             <div className="absolute w-2 h-2 bg-blue-400 rounded-full glow-blue" />
          </motion.div>
          
          <div className="absolute bottom-4 left-4 right-4 text-center">
             <div className="text-[10px] text-slate-500 font-mono mb-1 uppercase tracking-tighter">Dynamic Visualizer</div>
             <div className="text-[9px] text-slate-400 leading-tight">
               {isWhitelisted ? 'institutional address authenticated' : 'waiting for institutional whitelist status'}
             </div>
          </div>
       </div>

       <div className="space-y-6">
         <div>
           <div className="flex justify-between items-end mb-2">
             <span className="text-xs font-bold text-white leading-none">
                {steps[step-1].name}
             </span>
             <span className="text-[10px] text-slate-500 font-mono">{progress}%</span>
           </div>
           <div className="w-full h-1.5 bg-white/5 rounded-full overflow-hidden">
             <motion.div 
               className={`h-full rounded-full shadow-[0_0_10px_rgba(59,130,246,0.5)] ${isWhitelisted ? 'bg-green-500' : 'bg-blue-500'}`}
               initial={{ width: '0%' }}
               animate={{ width: `${progress}%` }}
               transition={{ ease: "linear" }}
             />
           </div>
         </div>

         <div className="space-y-4">
           {steps.map((s) => (
             <div key={s.id} className="flex items-start gap-3">
                <div className="mt-0.5">
                  {s.id < step ? (
                    <CheckCircle2 className="w-3.5 h-3.5 text-green-500" />
                  ) : s.id === step ? (
                    <Loader2 className="w-3.5 h-3.5 text-blue-400 animate-spin" />
                  ) : (
                    <div className="w-3.5 h-3.5 rounded-full border border-slate-700" />
                  )}
                </div>
                <div className="flex-1">
                   <div className={`text-xs font-medium ${s.id === step ? 'text-white' : 'text-slate-500'}`}>
                     {s.name}
                   </div>
                   {s.id === step && (
                     <motion.div 
                       initial={{ opacity: 0, y: -5 }}
                       animate={{ opacity: 1, y: 0 }}
                       className="text-[10px] text-slate-400 mt-0.5 leading-relaxed"
                     >
                       {s.desc}
                     </motion.div>
                   )}
                </div>
             </div>
           ))}
         </div>
       </div>

       <div className="mt-8 pt-6 border-t border-white/5 space-y-4">
         <div className="flex items-center justify-between text-[10px] text-slate-400">
           <span>Global Commitment</span>
           <span className="text-slate-300 font-mono">
             {ADDRESSES.Verifier.slice(0, 6)}...{ADDRESSES.Verifier.slice(-4)}
           </span>
         </div>
         <div className="flex items-center justify-between text-[10px] text-slate-400">
           <span>Reactive Relay</span>
           <span className="text-green-400 flex items-center gap-1">
             <div className="w-1 h-1 bg-green-400 rounded-full animate-pulse" />
             Relaying Events
           </span>
         </div>
         <button className="w-full py-2 bg-white/5 hover:bg-white/10 text-slate-400 hover:text-white rounded-lg text-[10px] flex items-center justify-center gap-2 border border-white/10 transition-colors">
            View Protocol Analytics <ExternalLink className="w-3 h-3" />
         </button>
       </div>
    </div>
  )
}
