"use client";
import React, { useEffect, useState } from "react";
import { api } from "@/lib/api";
import AdminGuard from "@/app/components/admin-guard";
import { useToast } from "@/app/components/ui/use-toast";

export default function RatesPage() {
  const [rates, setRates] = useState<any[]>([]);
  const [rate, setRate] = useState<string>("");
  const [base, setBase] = useState<string>("BYC");
  const [quote, setQuote] = useState<string>("USD");
  const [active, setActive] = useState<boolean>(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { toast } = useToast();
  const [deletingId, setDeletingId] = useState<string | null>(null);

  async function fetchRates() {
    try {
      setError(null);
      const res = await api.get("/v1/admin/rates");
      setRates(res.data);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    }
  }

  async function createRate(e: React.FormEvent) {
    e.preventDefault();
    try {
      setLoading(true);
      if (!rate || !Number(rate)) { setError("Enter a valid rate"); setLoading(false); return; }
      if (base === quote) { setError("Base and Quote must differ"); setLoading(false); return; }
      await api.post("/v1/admin/rates", { base, quote, rate: Number(rate), active });
      setRate("");
      setActive(true);
      await fetchRates();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { fetchRates(); }, []);

  return (
    <AdminGuard>
      <main style={{ padding: 24 }}>
        <h1 className="text-xl font-semibold">Conversion Rates</h1>
        <form onSubmit={createRate} className="mt-4 grid grid-cols-1 md:grid-cols-5 gap-2 items-end">
          <div>
            <label className="block text-sm mb-1">Base</label>
            <select value={base} onChange={e => setBase(e.target.value)} className="border px-3 py-2 rounded w-full">
              <option value="BYC">BYC</option>
              <option value="USD">USD</option>
              <option value="NGN">NGN</option>
            </select>
          </div>
          <div>
            <label className="block text-sm mb-1">Quote</label>
            <select value={quote} onChange={e => setQuote(e.target.value)} className="border px-3 py-2 rounded w-full">
              <option value="USD">USD</option>
              <option value="NGN">NGN</option>
              <option value="BYC">BYC</option>
            </select>
          </div>
          <div>
            <label className="block text-sm mb-1">Rate ({base}→{quote})</label>
            <input value={rate} onChange={e => setRate(e.target.value)} placeholder={`Rate (${base}→${quote})`} className="border px-3 py-2 rounded w-full" />
          </div>
          <div className="flex items-center gap-2">
            <input id="active" type="checkbox" checked={active} onChange={e => setActive(e.target.checked)} />
            <label htmlFor="active" className="text-sm">Active</label>
          </div>
          <button disabled={loading || !rate} className="bg-blue-600 text-white px-4 py-2 rounded">Create</button>
        </form>
        {error && <p className="text-red-600 mt-2">{error}</p>}
        <div className="mt-6">
          <table className="min-w-full text-sm">
            <thead><tr><th className="text-left">Base</th><th className="text-left">Quote</th><th className="text-left">Rate</th><th className="text-left">Active</th><th className="text-left">Created</th><th></th></tr></thead>
            <tbody>
              {rates.map((r) => (
                <tr key={r.id} className="border-t">
                  <td>{r.base}</td>
                  <td>{r.quote}</td>
                  <td>{r.rate}</td>
                  <td>{r.active ? 'Yes' : 'No'}</td>
                  <td>{new Date(r.createdAt).toLocaleString()}</td>
                  <td className="text-right">
                    <button
                      type="button"
                      className="px-3 py-1 border rounded text-red-600"
                      onClick={async () => {
                        try {
                          setDeletingId(r.id);
                          const res = await api.delete(`/v1/admin/rates/${r.id}`);
                          if (res.data?.ok) {
                            // Optimistic update
                            setRates((prev) => prev.filter((x) => x.id !== r.id));
                            toast({ title: 'Rate deleted' });
                          } else {
                            toast({ title: 'Delete failed', description: res.data?.error || 'Unknown error', variant: 'destructive' });
                          }
                        } catch (e: any) {
                          toast({ title: 'Delete failed', description: e?.response?.data?.message || e.message, variant: 'destructive' });
                        } finally {
                          setDeletingId(null);
                        }
                      }}
                      disabled={deletingId === r.id}
                    >{deletingId === r.id ? 'Deleting…' : 'Delete'}</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </main>
    </AdminGuard>
  );
}
