// Reemplazar LINKEN_ADDRESS con la address real después del deploy
export const LINKEN_ADDRESS = (process.env.NEXT_PUBLIC_LINKEN_ADDRESS ?? "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const LINKEN_ABI = [
  // Read
  { name: "name",        type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "string" }] },
  { name: "symbol",      type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "string" }] },
  { name: "totalSupply", type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { name: "MAX_SUPPLY",  type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
  { name: "paused",      type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "bool" }] },
  { name: "owner",       type: "function", stateMutability: "view", inputs: [], outputs: [{ type: "address" }] },
  {
    name: "balanceOf",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
  },
  // Write
  {
    name: "mint",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "to", type: "address" }, { name: "amount", type: "uint256" }],
    outputs: [],
  },
  {
    name: "burn",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
  {
    name: "pause",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
  {
    name: "unpause",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
  // Events
  {
    name: "Minted",
    type: "event",
    inputs: [{ name: "to", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }],
  },
  {
    name: "Burned",
    type: "event",
    inputs: [{ name: "from", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }],
  },
] as const;
