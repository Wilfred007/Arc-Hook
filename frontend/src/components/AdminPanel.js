'use client'

import React, { useState, useEffect, useRef } from 'react'
import { UserPlus, UserMinus, ShieldAlert, Loader2, CheckCircle } from 'lucide-react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { ADDRESSES, ABIS, NETWORKS, APP_CONFIG } from '@/lib/constants'
import { Toast, TOAST_TYPES } from './Toast'

export default function AdminPanel() {
  const { address, isConnected } = useAccount()
  const [targetAddress, setTargetAddress] = useState('')
  const [mounted, setMounted] = useState(false)
  const [toasts, setToasts] = useState([])
  const [isSyncing, setIsSyncing] = useState(false)
  const syncTimeoutRef = useRef(null)
  const syncToastRef = useRef(null)

  const addToast = (message, type, duration = 5000) => {
    const id = Date.now()
    setToasts((prev) => [...prev, { id, message, type, duration, onClose: () => removeToast(id) }])
    return id
  }

  const removeToast = (id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id))
  }

  const updateToast = (id, newToast) => {
    setToasts((prev) => prev.map((t) => t.id === id ? { ...t, ...newToast } : t))
  }

  useEffect(() => setMounted(true), [])

  // 1. Fetch current Registry Nonce
  const { data: registryNonce, refetch: refetchRegistry } = useReadContract({
    address: ADDRESSES.Registry,
    abi: ABIS.Registry,
    functionName: 'nonce',
    chainId: NETWORKS.Demo,
    query: {
      refetchInterval: isSyncing ? 3000 : 30000,
    }
  })

  // 2. Fetch current Verifier lastNonce
  const { data: verifierNonce, refetch: refetchVerifier } = useReadContract({
    address: ADDRESSES.Verifier,
    abi: ABIS.Verifier,
    functionName: 'lastNonce',
    chainId: NETWORKS.Demo,
    query: {
      refetchInterval: isSyncing ? 3000 : 30000,
    }
  })

  // Check if current user is owner
  const { data: owner } = useReadContract({
    address: ADDRESSES.Registry,
    abi: ABIS.Registry,
    functionName: 'owner',
    chainId: NETWORKS.Demo,
  })

  const { writeContract, data: hash, isPending, error: writeError } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const isOwner = address && owner && address.toLowerCase() === owner.toLowerCase()

  // Auto-clear syncing when on-chain state matches or exceeds expected nonce
  useEffect(() => {
    if (isSyncing && verifierNonce !== undefined && registryNonce !== undefined) {
      if (Number(verifierNonce) >= Number(registryNonce)) {
        setIsSyncing(false)
        
        // Remove the loading toast if it exists
        if (syncToastRef.current) {
          removeToast(syncToastRef.current)
          syncToastRef.current = null
        }
        
        addToast("Sync Complete! The institutional whitelist has been updated on-chain.", TOAST_TYPES.SUCCESS)
      }
    }
  }, [isSyncing, verifierNonce, registryNonce])

  // Monitor for transaction confirmations
  useEffect(() => {
    if (isSuccess && hash) {
      const id = addToast("Transaction confirmed! Starting cross-chain synchronization...", TOAST_TYPES.LOADING, 0)
      syncToastRef.current = id
      setIsSyncing(true)
      refetchRegistry()
    }
  }, [isSuccess, hash])

  useEffect(() => {
    if (writeError) {
      // Clear sync toast if transaction fails
      if (syncToastRef.current) {
        removeToast(syncToastRef.current)
        syncToastRef.current = null
      }
      addToast(`Error: ${writeError.shortMessage || writeError.message}`, TOAST_TYPES.ERROR)
    }
  }, [writeError])

  const handleAdd = () => {
    writeContract({
      address: ADDRESSES.Registry,
      abi: ABIS.Registry,
      functionName: 'addAddress',
      args: [targetAddress],
      chainId: NETWORKS.Demo,
    })
    addToast(`Sending transaction to ${APP_CONFIG.chainName}...`, TOAST_TYPES.INFO, 3000)
  }

  const handleRemove = () => {
    writeContract({
      address: ADDRESSES.Registry,
      abi: ABIS.Registry,
      functionName: 'removeAddress',
      args: [targetAddress],
      chainId: NETWORKS.Demo,
    })
    addToast(`Sending transaction to ${APP_CONFIG.chainName}...`, TOAST_TYPES.INFO, 3000)
  }

  if (!mounted || !isConnected) return null

  if (owner === undefined) {
    return (
      <div className="glass rounded-2xl p-6 w-full max-w-2xl border-blue-500/20 bg-blue-500/5 mt-12 flex items-center justify-center gap-3">
        <Loader2 className="w-5 h-5 text-blue-400 animate-spin" />
        <span className="text-slate-400 text-xs uppercase tracking-widest font-bold">Verifying Admin Rights...</span>
      </div>
    )
  }

  if (!isOwner) return null

  return (
    <>
      <div className="glass rounded-2xl p-6 w-full max-w-2xl border-blue-500/20 bg-blue-500/5 mt-12">
        <div className="flex items-center gap-2 mb-6">
          <ShieldAlert className="w-5 h-5 text-blue-400" />
          <h2 className="font-bold text-sm uppercase tracking-widest text-white">Institutional Registry Admin</h2>
        </div>

        <div className="flex flex-col md:flex-row gap-4">
          <div className="flex-1">
            <label className="text-[10px] text-slate-500 uppercase font-bold mb-1 block">Institutional Address</label>
            <input 
              type="text" 
              value={targetAddress}
              onChange={(e) => setTargetAddress(e.target.value)}
              className="w-full bg-white/5 border border-white/10 rounded-lg px-4 py-2 text-sm font-mono focus:outline-none focus:border-blue-500/50"
              placeholder="0x..."
            />
          </div>
          <div className="flex gap-2 items-end">
            <button 
              disabled={isPending || isConfirming || isSyncing || !targetAddress}
              onClick={handleAdd}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg text-xs font-bold flex items-center gap-2 disabled:opacity-50 transition-all font-mono"
            >
              {(isPending || isConfirming || isSyncing) ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserPlus className="w-4 h-4" />}
              {isSyncing ? 'SYNCING' : 'Add'}
            </button>
            <button 
              disabled={isPending || isConfirming || isSyncing || !targetAddress}
              onClick={handleRemove}
              className="px-4 py-2 bg-red-600/20 hover:bg-red-600/40 text-red-400 border border-red-500/20 rounded-lg text-xs font-bold flex items-center gap-2 disabled:opacity-50 transition-all font-mono"
            >
              <UserMinus className="w-4 h-4" />
              Remove
            </button>
          </div>
        </div>

        {/* Sync Status Indicator */}
        <div className="mt-6 pt-6 border-t border-white/10 flex items-center justify-between text-[10px] uppercase font-bold tracking-wider">
          <div className="flex items-center gap-4">
            <div className="flex flex-col">
              <span className="text-slate-500 mb-1">Registry Nonce</span>
              <span className="text-white bg-white/5 px-2 py-1 rounded border border-white/10">{registryNonce?.toString() || '0'}</span>
            </div>
            <div className="flex flex-col">
              <span className="text-slate-500 mb-1">Verifier Sync</span>
              <span className={`px-2 py-1 rounded border ${Number(verifierNonce) >= Number(registryNonce) ? 'text-green-400 bg-green-400/5 border-green-500/20' : 'text-blue-400 bg-blue-400/5 border-blue-500/20 animate-pulse'}`}>
                {verifierNonce?.toString() || '0'}
              </span>
            </div>
          </div>
          <div className="flex flex-col items-end">
            <span className="text-slate-500 mb-1">Prover Status</span>
            <span className="text-white flex items-center gap-2">
              <div className={`w-2 h-2 rounded-full ${isSyncing ? 'bg-blue-500 animate-ping' : 'bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.5)]'}`} />
              {isSyncing ? 'Synchronizing' : 'Operational'}
            </span>
          </div>
        </div>
      </div>

      {/* Toasts */}
      <div className="fixed inset-0 pointer-events-none z-50 overflow-hidden">
        <div className="absolute bottom-0 right-0 p-8 flex flex-col gap-4 pointer-events-auto">
          {toasts.map((toast) => (
            <Toast key={toast.id} {...toast} />
          ))}
        </div>
      </div>
    </>
  )
}
