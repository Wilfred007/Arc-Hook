'use client'

import React from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { CheckCircle, Info, Loader2, XCircle, X } from 'lucide-react'

export const TOAST_TYPES = {
  SUCCESS: 'success',
  INFO: 'info',
  ERROR: 'error',
  LOADING: 'loading'
}

export function Toast({ message, type = TOAST_TYPES.INFO, onClose, duration = 5000 }) {
  React.useEffect(() => {
    if (type !== TOAST_TYPES.LOADING && duration > 0) {
      const timer = setTimeout(onClose, duration)
      return () => clearTimeout(timer)
    }
  }, [type, duration, onClose])

  const icons = {
    [TOAST_TYPES.SUCCESS]: <CheckCircle className="w-5 h-5 text-green-400" />,
    [TOAST_TYPES.INFO]: <Info className="w-5 h-5 text-blue-400" />,
    [TOAST_TYPES.ERROR]: <XCircle className="w-5 h-5 text-red-400" />,
    [TOAST_TYPES.LOADING]: <Loader2 className="w-5 h-5 text-blue-400 animate-spin" />
  }

  const bgColors = {
    [TOAST_TYPES.SUCCESS]: 'bg-green-500/10 border-green-500/20',
    [TOAST_TYPES.INFO]: 'bg-blue-500/10 border-blue-500/20',
    [TOAST_TYPES.ERROR]: 'bg-red-500/10 border-red-500/20',
    [TOAST_TYPES.LOADING]: 'bg-white/5 border-white/10'
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 50, scale: 0.9 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, scale: 0.9, transition: { duration: 0.2 } }}
      className={`fixed bottom-8 right-8 z-50 flex items-center gap-3 p-4 pr-10 rounded-xl border backdrop-blur-md shadow-2xl ${bgColors[type]} min-w-[320px]`}
    >
      <div className="shrink-0">{icons[type]}</div>
      <div className="grow">
        <p className="text-white text-sm font-medium">{message}</p>
      </div>
      <button 
        onClick={onClose}
        className="absolute top-4 right-4 text-white/40 hover:text-white transition-colors"
      >
        <X className="w-4 h-4" />
      </button>
    </motion.div>
  )
}

export function ToastContainer({ toasts }) {
  return (
    <div className="fixed inset-0 pointer-events-none z-50">
      <AnimatePresence>
        {toasts.map((toast) => (
          <Toast key={toast.id} {...toast} />
        ))}
      </AnimatePresence>
    </div>
  )
}
