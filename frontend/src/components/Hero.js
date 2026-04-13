'use client'

import React, { useState, useEffect } from 'react'
import { motion, useScroll, useTransform, useSpring } from 'framer-motion'
import { Shield, ChevronRight, ArrowRight, Lock, EyeOff, Zap } from 'lucide-react'

export default function Hero({ onLaunch }) {
  const [mounted, setMounted] = useState(false)
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 })

  useEffect(() => {
    setMounted(true)
    const handleMouseMove = (e) => {
      setMousePosition({
        x: (e.clientX / window.innerWidth - 0.5) * 20,
        y: (e.clientY / window.innerHeight - 0.5) * 20
      })
    }
    window.addEventListener('mousemove', handleMouseMove)
    return () => window.removeEventListener('mousemove', handleMouseMove)
  }, [])

  const springX = useSpring(mousePosition.x, { stiffness: 50, damping: 20 })
  const springY = useSpring(mousePosition.y, { stiffness: 50, damping: 20 })

  if (!mounted) return null

  return (
    <div className="relative min-h-[90vh] flex flex-col items-center justify-center overflow-hidden pt-20">
      {/* 3D Animated Background Elements */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        <motion.div 
          style={{ x: springX, y: springY }}
          className="absolute top-1/4 left-1/4 w-[400px] h-[400px] bg-blue-600/10 blur-[120px] rounded-full" 
        />
        <motion.div 
          style={{ x: -springX, y: -springY }}
          className="absolute bottom-1/4 right-1/4 w-[500px] h-[500px] bg-purple-600/10 blur-[150px] rounded-full" 
        />
      </div>

      <div className="max-w-7xl mx-auto px-4 flex flex-col items-center text-center relative z-10">
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 1, ease: "easeOut" }}
          className="mb-8 p-1 rounded-full bg-linear-to-r from-blue-500/20 to-purple-500/20 border border-white/5 backdrop-blur-sm"
        >
          <div className="px-4 py-1.5 rounded-full bg-[#020617]/40 flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-blue-500 animate-pulse" />
            <span className="text-[10px] font-bold uppercase tracking-[0.2em] text-blue-400">Institutional Privacy V1.0</span>
          </div>
        </motion.div>

        <motion.h1 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          className="text-5xl md:text-7xl lg:text-8xl font-black tracking-tight leading-[0.9] mb-8"
        >
          PRIVATE DEFI. <br />
          <span className="text-transparent bg-clip-text bg-linear-to-b from-white to-white/40">
            UNCHAINED.
          </span>
        </motion.h1>

        <motion.p 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1, delay: 0.5 }}
          className="text-slate-400 text-lg md:text-xl max-w-2xl leading-relaxed mb-12"
        >
          The professional-grade privacy layer for Uniswap v4. <b>Arc Hook</b> leverages KZG commitments to deliver verifiable compliance without compromising institutional anonymity.
        </motion.p>

        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.8 }}
          className="flex flex-col sm:flex-row gap-4 items-center"
        >
          <button 
            onClick={onLaunch}
            className="px-8 py-4 bg-white text-black font-bold rounded-xl hover:bg-blue-50 hover:scale-105 active:scale-95 transition-all flex items-center gap-2 group shadow-[0_0_30px_rgba(255,255,255,0.2)]"
          >
            Launch Private App <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
          </button>
          <button className="px-8 py-4 bg-white/5 border border-white/10 text-white font-bold rounded-xl hover:bg-white/10 transition-all">
            Read Whitepaper
          </button>
        </motion.div>

        {/* 3D Visualizer (Shield, Arc, Hook) */}
        <div className="mt-20 relative w-full max-w-lg aspect-square flex items-center justify-center">
            {/* The Shield (Back) */}
            <motion.div 
               animate={{ 
                 y: [0, -20, 0],
                 rotateY: [0, 10, -10, 0]
               }}
               transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
               className="absolute w-64 h-80 opacity-20"
            >
               <svg viewBox="0 0 100 120" className="w-full h-full fill-blue-500">
                  <path d="M50 0 L0 25 L0 75 Q50 120 100 75 L100 25 Z" />
               </svg>
            </motion.div>

            {/* The Arc (Middle) */}
            <motion.div 
               animate={{ 
                 rotate: [0, 360],
                 scale: [1, 1.1, 1]
               }}
               transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
               className="absolute w-80 h-80 border-2 border-white/10 rounded-full border-t-blue-500/50"
            />
            
            <motion.div 
               animate={{ 
                 rotate: [360, 0],
                 scale: [1, 0.9, 1]
               }}
               transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
               className="absolute w-72 h-72 border border-white/5 rounded-full border-b-purple-500/40"
            />

            {/* The Hook (Center) */}
            <motion.div
               animate={{ 
                 scale: [1, 1.1, 1],
                 rotateY: [0, 360]
               }}
               transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
               className="relative z-20"
            >
                <div className="w-24 h-24 bg-linear-to-br from-blue-400 to-purple-600 rounded-2xl glow-blue flex items-center justify-center shadow-[0_0_50px_rgba(59,130,246,0.5)]">
                    <Lock className="w-10 h-10 text-white" />
                </div>
            </motion.div>

            {/* Feature Points */}
            <FeaturePoint delay={1} icon={<Zap />} text="High Liquidity" className="top-0 left-0" />
            <FeaturePoint delay={1.5} icon={<EyeOff />} text="Private" className="top-1/4 -right-12" />
            <FeaturePoint delay={2} icon={<Shield />} text="Compliant" className="bottom-1/4 -left-12" />
        </div>
      </div>
    </div>
  )
}

function FeaturePoint({ icon, text, className, delay }) {
  return (
    <motion.div 
      initial={{ opacity: 0, scale: 0 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay, duration: 0.5 }}
      whileHover={{ scale: 1.1 }}
      className={`absolute flex items-center gap-3 glass p-3 rounded-2xl border-white/10 z-30 cursor-pointer ${className}`}
    >
      <div className="w-8 h-8 rounded-lg bg-blue-500/20 flex items-center justify-center text-blue-400">
        {React.cloneElement(icon, { size: 16 })}
      </div>
      <span className="text-xs font-bold text-white pr-2">{text}</span>
    </motion.div>
  )
}
