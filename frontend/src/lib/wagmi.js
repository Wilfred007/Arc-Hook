import { http, createConfig } from 'wagmi'
import { mainnet, sepolia } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

export const unichainSepolia = {
  id: 1301,
  name: 'Unichain Sepolia',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://sepolia.unichain.org'] },
  },
  blockExplorers: {
    default: { name: 'Explorer', url: 'https://sepolia.unichain.org' },
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
  chains: [unichainSepolia, reactiveLasna, mainnet, sepolia],
  connectors: [injected()],
  transports: {
    [unichainSepolia.id]: http(),
    [reactiveLasna.id]: http(),
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
})
