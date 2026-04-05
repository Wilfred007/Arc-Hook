import WhitelistRegistry from './abis/WhitelistRegistry.json'
import WhitelistVerifier from './abis/WhitelistVerifier.json'
import KZGWhitelistHook from './abis/KZGWhitelistHook.json'
import ProverTrigger from './abis/ProverTrigger.json'
import KZGWhitelistRSC from './abis/KZGWhitelistRSC.json'
import PoolSwapTest from './abis/PoolSwapTest.json'

export const ADDRESSES = {
  Registry: process.env.NEXT_PUBLIC_REGISTRY_ADDRESS,
  Verifier: process.env.NEXT_PUBLIC_VERIFIER_ADDRESS,
  Trigger: process.env.NEXT_PUBLIC_TRIGGER_ADDRESS,
  Hook: process.env.NEXT_PUBLIC_HOOK_ADDRESS,
  RSC: process.env.NEXT_PUBLIC_RSC_ADDRESS,
  PoolManager: process.env.NEXT_PUBLIC_POOL_MANAGER,
  Token0: process.env.NEXT_PUBLIC_TOKEN0,
  Token1: process.env.NEXT_PUBLIC_TOKEN1,
  Router: process.env.NEXT_PUBLIC_SWAP_ROUTER,
}

export const ABIS = {
  Registry: WhitelistRegistry.abi,
  Verifier: WhitelistVerifier.abi,
  Hook: KZGWhitelistHook.abi,
  Trigger: ProverTrigger.abi,
  RSC: KZGWhitelistRSC.abi,
  Router: PoolSwapTest.abi,
}

export const NETWORKS = {
  UnichainSepolia: 1301,
  ReactiveLasna: 5318007,
}
