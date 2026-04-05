'use client'

import React, { useState, useEffect } from 'react'
import { UserPlus, UserMinus, ShieldAlert, Loader2, CheckCircle } from 'lucide-react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { ADDRESSES, ABIS, NETWORKS } from '@/lib/constants'

export default function AdminPanel() {
  const { address, isConnected } = useAccount()
  const [targetAddress, setTargetAddress] = useState('')
  const [mounted, setMounted] = useState(false)

  useEffect(() => setMounted(true), [])

  // Check if current user is owner
  const { data: owner } = useReadContract({
    address: ADDRESSES.Registry,
    abi: ABIS.Registry,
    functionName: 'owner',
    chainId: NETWORKS.UnichainSepolia,
  })

  const { writeContract, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const isOwner = address && owner && address.toLowerCase() === owner.toLowerCase()

  const handleAdd = () => {
    writeContract({
      address: ADDRESSES.Registry,
      abi: ABIS.Registry,
      functionName: 'addAddress',
      args: [targetAddress],
    })
  }

  const handleRemove = () => {
    writeContract({
      address: ADDRESSES.Registry,
      abi: ABIS.Registry,
      functionName: 'removeAddress',
      args: [targetAddress],
    })
  }

  if (!mounted || !isConnected || !isOwner) return null

  return (
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
            disabled={isPending || isConfirming || !targetAddress}
            onClick={handleAdd}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded-lg text-xs font-bold flex items-center gap-2 disabled:opacity-50 transition-all"
          >
            {isPending ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserPlus className="w-4 h-4" />}
            Add
          </button>
          <button 
            disabled={isPending || isConfirming || !targetAddress}
            onClick={handleRemove}
            className="px-4 py-2 bg-red-600/20 hover:bg-red-600/40 text-red-400 border border-red-500/20 rounded-lg text-xs font-bold flex items-center gap-2 disabled:opacity-50 transition-all"
          >
            <UserMinus className="w-4 h-4" />
            Remove
          </button>
        </div>
      </div>

      {isSuccess && (
        <div className="mt-4 p-3 bg-green-500/10 border border-green-500/20 rounded-lg flex items-center gap-2 text-green-400 text-[10px]">
          <CheckCircle className="w-4 h-4" />
          Registry updated successfully. Reactive Network will now propagate the change.
          <a href={`https://sepolia.unichain.org/tx/${hash}`} target="_blank" className="underline ml-auto">View Tx</a>
        </div>
      )}

      {error && (
        <div className="mt-4 p-3 bg-red-500/10 border border-red-500/20 rounded-lg text-red-400 text-[10px]">
          Error: {error.shortMessage || error.message}
        </div>
      )}
    </div>
  )
}
