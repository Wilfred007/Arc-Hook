'use client'

import React, { useEffect, useState } from 'react'
import { Shield, User, Bell, Settings } from 'lucide-react'
import { useAccount, useConnect, useDisconnect } from 'wagmi'

export default function Navbar() {
  const { address, isConnected } = useAccount()
  const { connectors, connect } = useConnect()
  const { disconnect } = useDisconnect()
  const [mounted, setMounted] = useState(false)

  // Avoid hydration mismatch
  useEffect(() => setMounted(true), [])

  if (!mounted) return (
    <nav className="border-b border-white/10 bg-[#020617]/80 backdrop-blur-md sticky top-0 z-50 h-16" />
  )

  return (
    <nav className="border-b border-white/10 bg-[#020617]/80 backdrop-blur-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <img src="/logo.png" className="w-8 h-8 rounded" alt="Arc Hook Logo" />
          <span className="font-bold text-xl tracking-tight hidden sm:block">
            ARC HOOK
          </span>
        </div>

        <div className="flex items-center gap-8 text-sm text-slate-400 font-medium">
          <a href="#" className="hover:text-white transition-colors text-white">Home</a>
          <a href="#" className="hover:text-white transition-colors">Trades</a>
          <a href="#" className="hover:text-white transition-colors">Markets</a>
          <a href="#" className="hover:text-white transition-colors">Portfolio</a>
          <a href="#" className="hover:text-white transition-colors">Analytics</a>
        </div>

        <div className="flex items-center gap-4">
          <div className="hidden md:flex items-center gap-2 mr-4">
            <Bell className="w-5 h-5 text-slate-400 cursor-pointer hover:text-white" />
            <Settings className="w-5 h-5 text-slate-400 cursor-pointer hover:text-white" />
          </div>

          {!isConnected ? (
            <button
              onClick={() => connect({ connector: connectors[0] })}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded font-medium transition-all"
            >
              Connect Wallet
            </button>
          ) : (
            <div className="flex items-center gap-3 bg-white/5 px-3 py-1.5 rounded-full border border-white/10">
              <div className="w-6 h-6 bg-slate-700 rounded-full flex items-center justify-center">
                <User className="w-4 h-4 text-slate-300" />
              </div>
              <span className="text-xs font-mono text-slate-300">
                {address?.slice(0, 6)}...{address?.slice(-4)}
              </span>
              <button 
                onClick={() => disconnect()}
                className="text-[10px] text-red-400 ml-1 hover:text-red-300"
              >
                Disconnect
              </button>
            </div>
          )}
        </div>
      </div>
    </nav>
  )
}
