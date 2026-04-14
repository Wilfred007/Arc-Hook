'use client'

import React, { useState, useEffect } from 'react'
import { ArrowDownUp, ShieldCheck, Lock, Loader2, AlertCircle } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useAccount, useBalance, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { ADDRESSES, ABIS, NETWORKS, APP_CONFIG } from '@/lib/constants'

export default function PrivateSwap() {
  const { address, isConnected, chainId } = useAccount()
  const { data: ethBalance } = useBalance({ 
    address, 
    chainId: NETWORKS.Demo 
  })
  
  const [fromAmount, setFromAmount] = useState('0.1')
  const [mounted, setMounted] = useState(false)
  const [proofData, setProofData] = useState(null)
  const [isProofLoading, setIsProofLoading] = useState(false)

  // Avoid hydration mismatch
  useEffect(() => setMounted(true), [])

  // Check if current user is whitelisted before fetching proof
  const { data: isWhitelisted } = useReadContract({
    address: ADDRESSES.Registry,
    abi: ABIS.Registry,
    functionName: 'isWhitelisted',
    args: [address],
    chainId: NETWORKS.Demo,
    query: {
      enabled: !!address,
    }
  })

  // Fetch KZG proof from local prover API
  useEffect(() => {
    if (!address || !isConnected || !isWhitelisted) {
      setProofData(null)
      return
    }

    const fetchProof = async () => {
      setIsProofLoading(true)
      try {
        const response = await fetch(`${APP_CONFIG.proverApiBase}/proof/${address}`)
        if (response.ok) {
          const data = await response.json()
          setProofData(data.hook_data)
        } else {
          setProofData(null)
        }
      } catch (err) {
        // Silently fail if not found to avoid console noise for non-whitelisted users
        setProofData(null)
      } finally {
        setIsProofLoading(false)
      }
    }

    fetchProof()
    const interval = setInterval(fetchProof, 15000) // Poll every 15s
    return () => clearInterval(interval)
  }, [address, isConnected, isWhitelisted])

  // Read commitment from Verifier
  const { data: commitment, isLoading: isCommitmentLoading } = useReadContract({
    address: ADDRESSES.Verifier,
    abi: ABIS.Verifier,
    functionName: 'commitment',
    chainId: NETWORKS.Demo,
  })

  // State for UI feedback
  const [verifyStatus, setVerifyStatus] = useState('idle') // idle, verifying, success, error

  // Write contract for Swap
  const { writeContract: writeSwap, data: swapHash, isPending: isSwapPending, error: swapError } = useWriteContract()
  const { isLoading: isSwapWaiting, isSuccess: isSwapSuccess } = useWaitForTransactionReceipt({ 
    hash: swapHash,
    chainId: NETWORKS.Demo 
  })

  // Write contract for Approval
  const { writeContract: writeApprove, isPending: isApprovePending } = useWriteContract()

  // Log write error if any
  useEffect(() => {
    if (swapError) {
      console.error("Swap Transaction Error Detail:", swapError)
      alert(`Swap Error: ${swapError.shortMessage || swapError.message}`)
      setVerifyStatus('error')
    }
  }, [swapError])

  const handleSwap = async () => {
    if (!proofData) {
      alert("No KZG proof found for this address. Please ensure you are whitelisted in the Admin Panel.")
      return
    }

    setVerifyStatus('verifying')
    try {
      if (!ADDRESSES.Token0 || !ADDRESSES.Token1 || !ADDRESSES.Router || !ADDRESSES.Hook) {
        throw new Error("Missing required contract addresses in environment variables (Vercel Settings).")
      }

      const currency0 = ADDRESSES.Token0 < ADDRESSES.Token1 ? ADDRESSES.Token0 : ADDRESSES.Token1
      const currency1 = ADDRESSES.Token0 < ADDRESSES.Token1 ? ADDRESSES.Token1 : ADDRESSES.Token0
      
      writeSwap({
        address: ADDRESSES.Router,
        abi: ABIS.Router,
        functionName: 'swap',
        args: [
          {
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: ADDRESSES.Hook
          },
          {
            zeroForOne: true, 
            amountSpecified: BigInt(-1 * 10**15),
            sqrtPriceLimitX96: BigInt("4295128740")
          },
          {
            takeClaims: false,
            settleUsingBurn: false
          },
          proofData
        ],
        chainId: NETWORKS.Demo,
      })

    } catch (err) {
      console.error("Critical Swap Initiation Error:", err)
      alert(`Critical Error during swap initiation: ${err.message}`)
      setVerifyStatus('error')
    }
  }

  useEffect(() => {
    if (isSwapSuccess) {
      setVerifyStatus('success')
      setTimeout(() => setVerifyStatus('idle'), 5000)
    }
  }, [isSwapSuccess])

  const handleApprove = async () => {
    const currency0 = ADDRESSES.Token0 < ADDRESSES.Token1 ? ADDRESSES.Token0 : ADDRESSES.Token1
    writeApprove({
      address: currency0,
      abi: [
        {
          type: 'function',
          name: 'approve',
          inputs: [
            { name: 'spender', type: 'address' },
            { name: 'amount', type: 'uint256' }
          ],
          outputs: [{ name: '', type: 'bool' }],
          stateMutability: 'nonpayable'
        }
      ],
      functionName: 'approve',
      args: [ADDRESSES.Router, BigInt("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")],
      chainId: NETWORKS.Demo,
    })
  }

  if (!mounted) return <div className="glass rounded-2xl p-6 w-full max-w-md h-[500px] animate-pulse" />

  const isWrongNetwork = isConnected && chainId !== NETWORKS.Demo

  return (
    <div className="glass rounded-2xl p-6 w-full max-w-md relative overflow-hidden">
      <div className="absolute top-0 right-0 w-32 h-32 bg-blue-600/10 blur-3xl -z-10" />
      
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-lg font-bold flex items-center gap-2">
          Private Swap <span className="text-[10px] text-slate-500 font-normal py-0.5 px-1.5 border border-slate-700 rounded uppercase tracking-wider">{APP_CONFIG.chainName}</span>
        </h2>
        <SettingsIcon className="w-5 h-5 text-slate-400 cursor-pointer hover:text-white" />
      </div>

      {isWrongNetwork && (
        <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded-xl flex items-center gap-2 text-red-400 text-xs text-center justify-center">
          <AlertCircle className="w-4 h-4" />
          Please switch to {APP_CONFIG.chainName}
        </div>
      )}

      <div className="space-y-4">
        {/* From Section */}
        <div className="bg-white/5 rounded-xl p-4 border border-white/5">
          <div className="flex justify-between text-xs text-slate-400 mb-2">
            <span>From</span>
            <span>Institutional Balance</span>
          </div>
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-2 bg-white/10 px-3 py-1.5 rounded-lg">
              <div className="w-5 h-5 bg-red-600 rounded-full flex items-center justify-center text-[10px] font-bold">R</div>
              <span className="font-bold">RED</span>
            </div>
            <input 
              type="text" 
              value={fromAmount}
              onChange={(e) => setFromAmount(e.target.value)}
              className="bg-transparent text-right text-2xl font-bold focus:outline-none w-full ml-4"
              placeholder="0.0"
            />
          </div>
        </div>

        {/* Swap Arrow */}
        <div className="flex justify-center -my-6 relative z-10">
          <div className="bg-[#0f172a] p-2 rounded-xl border border-white/10 shadow-xl">
            <ArrowDownUp className="w-4 h-4 text-blue-400" />
          </div>
        </div>

        {/* To Section */}
        <div className="bg-white/5 rounded-xl p-4 border border-white/5">
          <div className="flex justify-between text-xs text-slate-400 mb-2">
            <span>To</span>
            <span className="opacity-50 italic">Private Destination</span>
          </div>
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-2 bg-white/10 px-3 py-1.5 rounded-lg">
              <div className="w-5 h-5 bg-blue-600 rounded-full flex items-center justify-center text-[10px] font-bold">B</div>
              <span className="font-bold">BLUE</span>
            </div>
            <div className="text-right text-2xl font-bold text-slate-300">
              {fromAmount ? (Number(fromAmount) * 1.0).toFixed(4) : '0.00'}
            </div>
          </div>
        </div>
      </div>

      <div className="mt-6 space-y-3 text-xs">
        <div className="flex justify-between text-slate-400">
          <span>Hook Status</span>
          <span className="text-blue-400 font-medium flex items-center gap-1">
            <ShieldCheck className="w-3 h-3" />
            KZG Verified
          </span>
        </div>
        <div className="flex justify-between text-slate-400">
          <span>Commitment</span>
          <span className="text-slate-200 font-mono">
            {commitment ? `${commitment.slice(0, 10)}...${commitment.slice(-8)}` : 'No Active WL'}
          </span>
        </div>
      </div>

      {!isSwapSuccess && (
        <div className="mt-6 flex gap-3">
          <button 
            disabled={!isConnected || isWrongNetwork || isApprovePending}
            onClick={handleApprove}
            className={`flex-1 py-4 text-white font-bold rounded-xl transition-all shadow-lg transform active:scale-[0.98] disabled:opacity-50 disabled:cursor-allowed flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-700`}
          >
            {isApprovePending ? <Loader2 className="w-5 h-5 animate-spin" /> : 'Approve RED'}
          </button>
          
          <button 
            disabled={!isConnected || isWrongNetwork || isSwapPending || !proofData}
            onClick={handleSwap}
            className={`flex-[2] py-4 text-white font-bold rounded-xl transition-all shadow-lg transform active:scale-[0.98] disabled:opacity-50 disabled:cursor-allowed flex items-center justify-center gap-2 ${
              verifyStatus === 'success' 
                ? 'bg-green-600 hover:bg-green-500 shadow-green-500/20' 
                : 'bg-linear-to-r from-blue-600 to-blue-500 hover:from-blue-500 hover:to-blue-400 glow-blue'
            }`}
          >
            {isSwapPending || isSwapWaiting ? (
              <><Loader2 className="w-5 h-5 animate-spin" /> {isSwapWaiting ? 'Confirming...' : 'Submitting Swap...'}</>
            ) : verifyStatus === 'success' ? (
              <><ShieldCheck className="w-5 h-5" /> Institutional Access Granted</>
            ) : (
              'Initiate Private Swap'
            )}
          </button>
        </div>
      )}

      {isSwapSuccess && (
        <div className="mt-6 p-4 bg-green-500/10 border border-green-500/20 rounded-xl text-center">
          <div className="text-green-400 font-bold flex items-center justify-center gap-2 mb-1">
            <ShieldCheck className="w-5 h-5" /> Swap Executed Privately
          </div>
          <a 
            href={`${APP_CONFIG.explorerBaseUrl}/tx/${swapHash}`} 
            target="_blank" 
            rel="noopener noreferrer"
            className="text-[10px] text-blue-400 hover:underline"
          >
            View on Explorer: {swapHash?.slice(0, 10)}...{swapHash?.slice(-8)}
          </a>
        </div>
      )}

      {/* ZK Status Banner */}
      <div className={`mt-4 p-3 border rounded-xl flex items-center gap-3 ${proofData ? 'bg-green-500/10 border-green-500/20' : 'bg-blue-500/10 border-blue-500/20'}`}>
        <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${proofData ? 'bg-green-500/20' : 'bg-blue-500/20'}`}>
          {proofData ? <ShieldCheck className="w-5 h-5 text-green-400" /> : <Lock className="w-5 h-5 text-blue-400" />}
        </div>
        <div className="flex-1">
          <div className="text-[11px] font-bold text-white uppercase tracking-wider">
            {proofData ? 'ZK-Proof Generated' : isProofLoading ? 'Generating Proof...' : 'ZK-Identification'}
          </div>
          <div className="text-[10px] text-slate-400 truncate max-w-[200px]">
            {isConnected 
              ? proofData 
                ? `Compliance verified for ${address.slice(0, 6)}...${address.slice(-4)}`
                : `No proof found for ${address.slice(0, 6)}...${address.slice(-4)}`
              : 'Connect wallet to verify institutional status'}
          </div>
        </div>
        {isConnected && (
          <div className={`w-8 h-8 rounded-full border-2 flex items-center justify-center ${proofData ? 'border-green-500' : 'border-blue-500'}`}>
             <div className={`w-1.5 h-1.5 rounded-full animate-pulse ${proofData ? 'bg-green-400' : 'bg-blue-400'}`} />
          </div>
        )}
      </div>
    </div>
  )
}

function SettingsIcon(props) {
  return (
    <svg {...props} width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.72V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.17a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>
    </svg>
  )
}
