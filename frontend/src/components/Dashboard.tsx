"use client";

import { useState } from "react";
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { formatUnits, parseUnits, isAddress } from "viem";
import { LINKEN_ABI, LINKEN_ADDRESS } from "@/lib/contract";

// ── helpers ──────────────────────────────────────────────────
function fmt(val: bigint | undefined) {
  if (val === undefined) return "—";
  return Number(formatUnits(val, 18)).toLocaleString("es-AR", { maximumFractionDigits: 2 });
}

function TxStatus({ hash }: { hash: `0x${string}` | undefined }) {
  const { isLoading, isSuccess } = useWaitForTransactionReceipt({ hash });
  if (!hash) return null;
  if (isLoading) return <p className="status loading">⏳ Confirmando transacción…</p>;
  if (isSuccess) return <p className="status ok">✅ Confirmada — <a href={`https://sepolia.etherscan.io/tx/${hash}`} target="_blank" rel="noreferrer">ver en Etherscan ↗</a></p>;
  return null;
}

// ── subcomponentes ────────────────────────────────────────────
function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="stat-card">
      <span className="stat-label">{label}</span>
      <span className="stat-value">{value}</span>
    </div>
  );
}

// ── panel genérico de acción ──────────────────────────────────
function ActionPanel({
  title,
  onSubmit,
  isPending,
  hash,
  children,
}: {
  title: string;
  onSubmit: () => void;
  isPending: boolean;
  hash: `0x${string}` | undefined;
  children: React.ReactNode;
}) {
  return (
    <div className="panel">
      <h3>{title}</h3>
      {children}
      <button onClick={onSubmit} disabled={isPending} className="btn-primary">
        {isPending ? "Enviando…" : "Confirmar"}
      </button>
      <TxStatus hash={hash} />
    </div>
  );
}

// ── dashboard principal ───────────────────────────────────────
export default function Dashboard() {
  const { address, isConnected } = useAccount();

  // ── reads ──
  const { data: balance,     refetch: refetchBalance }     = useReadContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "balanceOf", args: [address!], query: { enabled: !!address } });
  const { data: totalSupply, refetch: refetchSupply }      = useReadContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "totalSupply" });
  const { data: maxSupply }                                 = useReadContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "MAX_SUPPLY" });
  const { data: isPaused,    refetch: refetchPaused }      = useReadContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "paused" });
  const { data: owner }                                     = useReadContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "owner" });

  const isOwner = address && owner && address.toLowerCase() === (owner as string).toLowerCase();

  // ── writes ──
  const { writeContract, data: txHash, isPending } = useWriteContract();

  // ── estado local de formularios ──
  const [mintTo,     setMintTo]     = useState("");
  const [mintAmount, setMintAmount] = useState("");
  const [burnAmount, setBurnAmount] = useState("");

  const refetchAll = () => { refetchBalance(); refetchSupply(); refetchPaused(); };

  // ── handlers ──
  const handleMint = () => {
    if (!isAddress(mintTo) || !mintAmount) return;
    writeContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "mint", args: [mintTo as `0x${string}`, parseUnits(mintAmount, 18)] }, { onSuccess: refetchAll });
  };

  const handleBurn = () => {
    if (!burnAmount) return;
    writeContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "burn", args: [parseUnits(burnAmount, 18)] }, { onSuccess: refetchAll });
  };

  const handlePause   = () => writeContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "pause"   }, { onSuccess: refetchAll });
  const handleUnpause = () => writeContract({ address: LINKEN_ADDRESS, abi: LINKEN_ABI, functionName: "unpause" }, { onSuccess: refetchAll });

  // ── render ──
  return (
    <main className="main">
      <header className="header">
        <div className="logo">
          <span className="logo-symbol">⚡</span>
          <span className="logo-text">LINKEN <span className="logo-ticker">LKN</span></span>
        </div>
        <ConnectButton />
      </header>

      {isPaused && (
        <div className="alert-paused">⚠️ El contrato está PAUSADO — las transferencias están bloqueadas.</div>
      )}

      <section className="stats">
        <StatCard label="Tu balance"    value={`${fmt(balance)} LKN`} />
        <StatCard label="Supply total"  value={`${fmt(totalSupply)} LKN`} />
        <StatCard label="Supply máximo" value={`${fmt(maxSupply)} LKN`} />
        <StatCard label="Estado"        value={isPaused ? "🔴 Pausado" : "🟢 Activo"} />
      </section>

      {isConnected ? (
        <section className="actions">

          {/* Burn — cualquier holder */}
          <ActionPanel title="🔥 Quemar tokens" onSubmit={handleBurn} isPending={isPending} hash={txHash}>
            <input
              className="input"
              type="number"
              placeholder="Cantidad LKN"
              value={burnAmount}
              onChange={e => setBurnAmount(e.target.value)}
            />
          </ActionPanel>

          {/* Mint — solo owner */}
          {isOwner && (
            <ActionPanel title="🪙 Mintear tokens (owner)" onSubmit={handleMint} isPending={isPending} hash={txHash}>
              <input
                className="input"
                type="text"
                placeholder="Dirección destino (0x…)"
                value={mintTo}
                onChange={e => setMintTo(e.target.value)}
              />
              <input
                className="input"
                type="number"
                placeholder="Cantidad LKN"
                value={mintAmount}
                onChange={e => setMintAmount(e.target.value)}
              />
            </ActionPanel>
          )}

          {/* Pause / Unpause — solo owner */}
          {isOwner && (
            <div className="panel">
              <h3>🚨 Circuit-breaker (owner)</h3>
              <p className="panel-desc">
                Pausar bloquea todas las transferencias, mints y burns como medida de emergencia.
              </p>
              <div className="btn-row">
                <button onClick={handlePause}   disabled={isPending || !!isPaused}  className="btn-danger">Pausar</button>
                <button onClick={handleUnpause} disabled={isPending || !isPaused}   className="btn-success">Reanudar</button>
              </div>
              <TxStatus hash={txHash} />
            </div>
          )}

        </section>
      ) : (
        <div className="connect-prompt">
          <p>Conectá tu wallet para interactuar con el contrato.</p>
        </div>
      )}

      <footer className="footer">
        <a href={`https://sepolia.etherscan.io/address/${LINKEN_ADDRESS}`} target="_blank" rel="noreferrer">
          Ver contrato en Etherscan ↗
        </a>
      </footer>
    </main>
  );
}
