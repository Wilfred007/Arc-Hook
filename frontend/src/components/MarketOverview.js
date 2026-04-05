'use client'

import React from 'react'
import { TrendingUp, Activity, BarChart3, Layers } from 'lucide-react'

export default function MarketOverview() {
  const pools = [
    { id: 1, name: 'ETH / USDC', volume: '$124.5M', tvl: '$1.2B', change: '+2.4%' },
    { id: 2, name: 'WBTC / ETH', volume: '$89.2M', tvl: '$840M', change: '-0.8%' },
    { id: 3, name: 'UNI / ETH', volume: '$12.1M', tvl: '$150M', change: '+4.1%' },
  ]

  return (
    <div className="space-y-6 w-full max-w-2xl">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="glass p-4 rounded-xl border-white/5">
          <div className="flex items-center gap-2 mb-4 text-slate-400">
             <TrendingUp className="w-4 h-4" />
             <span className="text-xs font-bold uppercase tracking-wider">Market Overview</span>
          </div>
          <div className="space-y-4">
             {pools.map(pool => (
               <div key={pool.id} className="flex items-center justify-between p-2 hover:bg-white/5 rounded-lg transition-colors cursor-pointer">
                  <div>
                    <div className="text-sm font-bold">{pool.name}</div>
                    <div className="text-[10px] text-slate-500">Vol: {pool.volume}</div>
                  </div>
                  <div className="text-right">
                    <div className={`text-xs font-medium ${pool.change.startsWith('+') ? 'text-green-400' : 'text-red-400'}`}>
                      {pool.change}
                    </div>
                    <div className="text-[10px] text-slate-500">TVL: {pool.tvl}</div>
                  </div>
               </div>
             ))}
          </div>
        </div>

        <div className="glass p-4 rounded-xl border-white/5 flex flex-col">
          <div className="flex items-center gap-2 mb-4 text-slate-400">
             <Activity className="w-4 h-4" />
             <span className="text-xs font-bold uppercase tracking-wider">Liquidity Pools</span>
          </div>
          <div className="flex-1 flex flex-col justify-between">
             <div className="space-y-2">
                <div className="flex justify-between text-[10px] text-slate-500 uppercase tracking-tighter">
                  <span>Pool Depth</span>
                  <span>Util.</span>
                </div>
                {[1,2,3,4].map(i => (
                  <div key={i} className="w-full h-2 bg-white/5 rounded-full overflow-hidden">
                    <div className={`h-full bg-blue-500/50 rounded-full`} style={{ width: `${Math.random() * 60 + 20}%` }} />
                  </div>
                ))}
             </div>
             <div className="pt-4 flex items-center gap-4">
                <div className="flex items-center gap-1 text-[10px] text-slate-400">
                   <BarChart3 className="w-3 h-3 text-blue-400" /> 124 txns/h
                </div>
                <div className="flex items-center gap-1 text-[10px] text-slate-400">
                   <Layers className="w-3 h-3 text-purple-400" /> 2,421 LPs
                </div>
             </div>
          </div>
        </div>
      </div>

      <div className="glass p-6 rounded-2xl border-white/5 relative overflow-hidden h-64">
         <div className="absolute top-0 left-0 w-full h-full crypto-grid opacity-20" />
         <div className="relative z-10">
           <div className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-4">Volume History</div>
           <svg className="w-full h-40 mt-4 overflow-visible" viewBox="0 0 400 100">
              <defs>
                 <linearGradient id="gradient" x1="0%" y1="0%" x2="0%" y2="100%">
                    <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.4" />
                    <stop offset="100%" stopColor="#3b82f6" stopOpacity="0" />
                 </linearGradient>
              </defs>
              <path d="M0,80 Q50,40 100,60 T200,30 T300,50 T400,20 L400,100 L0,100 Z" fill="url(#gradient)" />
              <path d="M0,80 Q50,40 100,60 T200,30 T300,50 T400,20" fill="none" stroke="#3b82f6" strokeWidth="2" />
           </svg>
           <div className="flex justify-between text-[10px] text-slate-600 mt-2 uppercase">
              <span>08:00 AM</span>
              <span>12:00 PM</span>
              <span>04:00 PM</span>
              <span>08:00 PM</span>
           </div>
         </div>
      </div>
    </div>
  )
}
