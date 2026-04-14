import { http, createConfig } from 'wagmi'
import { mainnet, sepolia } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

const demoChainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? 133)
const demoChainName = process.env.NEXT_PUBLIC_CHAIN_NAME ?? 'HashKey Testnet'
const demoRpcUrl = process.env.NEXT_PUBLIC_CHAIN_RPC_URL ?? 'https://testnet.hsk.xyz'
const demoExplorerUrl = process.env.NEXT_PUBLIC_EXPLORER_BASE_URL ?? 'https://hashkey.blockscout.com'

export const demoChain = {
  id: demoChainId,
  name: demoChainName,
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: [demoRpcUrl] },
  },
  blockExplorers: {
    default: { name: 'Explorer', url: demoExplorerUrl },
  },
  testnet: true,
}

export const reactiveLasna = {
  id: 5318007,
  name: 'Reactive Lasna',
  nativeCurrency: { name: 'Reactive', symbol: 'REACT', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://lasna-rpc.rnk.dev/'] },
  },
  blockExplorers: {
    default: { name: 'ReactScan', url: 'https://reactscan.net' },
  },
  testnet: true,
}

export const config = createConfig({
  chains: [demoChain, reactiveLasna, mainnet, sepolia],
  connectors: [injected()],
  transports: {
    [demoChain.id]: http(),
    [reactiveLasna.id]: http(),
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
})
