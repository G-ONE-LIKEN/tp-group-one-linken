import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: "Linken LKN",
  // Reemplazar con tu WalletConnect Project ID (https://cloud.walletconnect.com)
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ?? "YOUR_PROJECT_ID",
  chains: [sepolia],
  ssr: true,
});
