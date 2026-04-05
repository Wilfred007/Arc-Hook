import { Web3Provider } from "@/lib/Web3Provider";
import "./globals.css";

export const metadata = {
  title: "Arc-Hook | Institutional Privacy",
  description: "Secure, private institutional swaps powered by KZG and Reactive Network",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className="antialiased bg-[#020617] text-slate-100 min-h-screen">
        <Web3Provider>
          {children}
        </Web3Provider>
      </body>
    </html>
  );
}
