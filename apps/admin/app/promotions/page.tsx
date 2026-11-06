"use client";
import React, { useEffect, useState } from "react";
import { api } from "@/lib/api";
import AdminGuard from "@/app/components/admin-guard";
import CreateFeedAdForm from "@/app/components/create-feed-ad-form";

type Tab = "wallet" | "feed-ads";

export default function PromotionsPage() {
  const [tab, setTab] = useState<Tab>("feed-ads");
  const [promos, setPromos] = useState<any[]>([]);
  const [slug, setSlug] = useState("");
  const [title, setTitle] = useState("");
  const [amount, setAmount] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function fetchPromos() {
    try {
      setError(null);
      const res = await api.get("/v1/admin/promotions");
      setPromos(res.data);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    }
  }

  async function createPromo(e: React.FormEvent) {
    e.preventDefault();
    try {
      setLoading(true);
      await api.post("/v1/admin/promotions", { slug, title, type: "manual", amountBYC: Number(amount) });
      setSlug("");
      setTitle("");
      setAmount("");
      await fetchPromos();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (tab === "wallet") fetchPromos();
  }, [tab]);

  return (
    <AdminGuard>
      <main style={{ padding: 24 }}>
        <h1 className="text-xl font-semibold">Marketing</h1>
        <p className="text-sm text-gray-500 mt-1 max-w-2xl">
          <strong>Feed ads</strong> are sponsored creatives in app feeds (trade, gift, donation) — they go through{" "}
          <strong>Ads Review</strong> before going live. <strong>BYC promotions</strong> are separate wallet credit
          campaigns (slug-based BYC amounts), not feed advertisements.
        </p>

        <motionDiv className="flex gap-2 mt-6 border-b">
          <TabButton active={tab === "feed-ads"} onClick={() => setTab("feed-ads")}>
            Create feed ad
          </TabButton>
          <TabButton active={tab === "wallet"} onClick={() => setTab("wallet")}>
            BYC wallet promotions
          </TabButton>
        </motionDiv>

        {tab === "feed-ads" ? (
          <motionDiv className="mt-8">
            <CreateFeedAdForm />
          </motionDiv>
        ) : (
          <motionDiv className="mt-8">
            <form onSubmit={createPromo} className="flex gap-2 flex-wrap">
              <input value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="Slug" className="border px-3 py-2 rounded" />
              <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Title" className="border px-3 py-2 rounded" />
              <input value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="Amount BYC" className="border px-3 py-2 rounded" />
              <button disabled={loading || !slug || !title || !amount} className="bg-blue-600 text-white px-4 py-2 rounded">
                Create promotion
              </button>
            </form>
            {error && <p className="text-red-600 mt-2">{error}</p>}
            <motionDiv className="mt-6 rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm overflow-hidden">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-gray-200 bg-gradient-to-r from-gray-50 to-gray-50 text-left text-gray-700 font-semibold">
                    <th className="px-6 py-4">Slug</th>
                    <th className="px-6 py-4">Title</th>
                    <th className="px-6 py-4">Amount</th>
                    <th className="px-6 py-4">Active</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {promos.map((p) => (
                    <tr key={p.id} className="hover:bg-gray-50 transition-all duration-200">
                      <td className="px-6 py-4 text-gray-900">{p.slug}</td>
                      <td className="px-6 py-4 text-gray-700">{p.title}</td>
                      <td className="px-6 py-4 text-gray-700">{p.amountBYC}</td>
                      <td className="px-6 py-4 text-gray-700">{String(p.active)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </motionDiv>
          </motionDiv>
        )}
      </main>
    </AdminGuard>
  );
}

function TabButton({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px ${
        active ? "border-indigo-600 text-indigo-700" : "border-transparent text-gray-500 hover:text-gray-700"
      }`}
    >
      {children}
    </button>
  );
}

function motionDiv({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={className}>{children}</div>;
}
