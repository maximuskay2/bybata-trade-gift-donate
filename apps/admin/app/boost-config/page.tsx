"use client";
import React, { useEffect, useState } from "react";
import { api } from "@/lib/api";
import AdminGuard from "@/app/components/admin-guard";

export default function BoostConfigPage() {
  const [configs, setConfigs] = useState<any[]>([]);
  const [types, setTypes] = useState<any[]>([]);
  const [placements, setPlacements] = useState<any[]>([]);

  const [boostTypeId, setBoostTypeId] = useState("");
  const [minDays, setMinDays] = useState("1");
  const [maxDays, setMaxDays] = useState("30");
  const [pricingModel, setPricingModel] = useState("FIXED");
  const [baseCostBYC, setBaseCostBYC] = useState("");
  const [dailyCostBYC, setDailyCostBYC] = useState("");
  const [placementKeys, setPlacementKeys] = useState<string[]>([]);
  const [tiers, setTiers] = useState("[]");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try {
      setError(null);
      const [cfgRes, typesRes, placementsRes] = await Promise.all([
        api.get("/v1/admin/boost-configs"),
        api.get("/v1/admin/boost-types"),
        api.get("/v1/admin/ad-placements"),
      ]);
      setConfigs(cfgRes.data);
      setTypes(typesRes.data);
      setPlacements(placementsRes.data);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    }
  }

  async function create(e: React.FormEvent) {
    e.preventDefault();
    try {
      setLoading(true);
      await api.post("/v1/admin/boost-configs", {
        boostTypeId,
        minDays: Number(minDays),
        maxDays: Number(maxDays),
        pricingModel,
        baseCostBYC: baseCostBYC ? Number(baseCostBYC) : undefined,
        dailyCostBYC: dailyCostBYC ? Number(dailyCostBYC) : undefined,
        tiers: tiers ? JSON.parse(tiers) : undefined,
        placementKeys,
      });
      setBoostTypeId("");
      setMinDays("1");
      setMaxDays("30");
      setPricingModel("FIXED");
      setBaseCostBYC("");
      setDailyCostBYC("");
      setPlacementKeys([]);
      setTiers("[]");
      await load();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  async function toggle(id: string, active: boolean) {
    await api.patch(`/v1/admin/boost-configs/${id}`, { active });
    await load();
  }

  useEffect(() => { load(); }, []);

  return (
    <AdminGuard>
      <main className="p-6 space-y-6">
        <h1 className="text-xl font-semibold">Boost Configurations</h1>
        <form onSubmit={create} className="grid gap-3 max-w-4xl">
          <select value={boostTypeId} onChange={e => setBoostTypeId(e.target.value)} className="border px-3 py-2 rounded">
            <option value="">Select Boost Type</option>
            {types.map((t) => (
              <option key={t.id} value={t.id}>{t.title}</option>
            ))}
          </select>
          <div className="grid grid-cols-2 gap-2">
            <input value={minDays} onChange={e => setMinDays(e.target.value)} placeholder="Min days" className="border px-3 py-2 rounded" />
            <input value={maxDays} onChange={e => setMaxDays(e.target.value)} placeholder="Max days" className="border px-3 py-2 rounded" />
          </div>
          <select value={pricingModel} onChange={e => setPricingModel(e.target.value)} className="border px-3 py-2 rounded">
            <option value="FIXED">FIXED</option>
            <option value="DAILY">DAILY</option>
            <option value="TIERED">TIERED</option>
          </select>
          <div className="grid grid-cols-2 gap-2">
            <input value={baseCostBYC} onChange={e => setBaseCostBYC(e.target.value)} placeholder="Base cost BYC" className="border px-3 py-2 rounded" />
            <input value={dailyCostBYC} onChange={e => setDailyCostBYC(e.target.value)} placeholder="Daily cost BYC" className="border px-3 py-2 rounded" />
          </div>
          <textarea value={tiers} onChange={e => setTiers(e.target.value)} placeholder='Tiers JSON: [{"minDays":1,"maxDays":7,"cost":20}]' className="border px-3 py-2 rounded h-24" />
          <div className="border rounded p-3">
            <div className="text-sm font-medium mb-2">Placements</div>
            <div className="flex flex-wrap gap-2">
              {placements.map((p) => (
                <label key={p.id} className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    checked={placementKeys.includes(p.key)}
                    onChange={(e) => {
                      setPlacementKeys((prev) => e.target.checked ? [...prev, p.key] : prev.filter((k) => k !== p.key));
                    }}
                  />
                  {p.title}
                </label>
              ))}
            </div>
          </div>
          <button disabled={loading || !boostTypeId} className="bg-blue-600 text-white px-4 py-2 rounded w-fit">Create</button>
        </form>
        {error && <p className="text-red-600">{error}</p>}
        <div className="overflow-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="text-left">
                <th className="py-2">Boost Type</th>
                <th>Days</th>
                <th>Pricing</th>
                <th>Placements</th>
                <th>Active</th>
              </tr>
            </thead>
            <tbody>
              {configs.map((c) => (
                <tr key={c.id} className="border-t">
                  <td className="py-2">{c.boostType?.title}</td>
                  <td>{c.minDays}-{c.maxDays}</td>
                  <td>{c.pricingModel}</td>
                  <td>{(c.placementKeys || []).join(", ")}</td>
                  <td>
                    <button className="text-blue-600" onClick={() => toggle(c.id, !c.active)}>
                      {String(c.active)}
                    </button>
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
