"use client";

import { useEffect, useState } from "react";
import PageHeader from "@/app/components/page-header";

export default function StatusPage() {
  const [status, setStatus] = useState<string>("loading...");
  const [timestamp, setTimestamp] = useState<string>("");
  const base = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000";

  useEffect(() => {
    const run = async () => {
      try {
        const res = await fetch(`${base}/health`, { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        setStatus(data.status || "ok");
        setTimestamp(data.timestamp || new Date().toISOString());
      } catch (e: any) {
        setStatus(`error: ${e.message}`);
      }
    };
    run();
  }, [base]);

  return (
    <main style={{ padding: 24 }}>
      <PageHeader title="Admin ⇄ API status" breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Status" }]} />
      <p>
        API: <b>{base}</b>
      </p>
      <p>
        Health: <b>{status}</b>
      </p>
      {timestamp && <p>Timestamp: {timestamp}</p>}
    </main>
  );
}
