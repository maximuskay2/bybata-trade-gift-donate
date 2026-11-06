"use client";
import React, { useEffect, useState } from "react";
import { api } from "@/lib/api";
import AdminGuard from "@/app/components/admin-guard";

export default function AdPlacementsPage() {
  const [items, setItems] = useState<any[]>([]);
  const [key, setKey] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState("0");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try {
      setError(null);
      const res = await api.get("/v1/admin/ad-placements");
      setItems(res.data);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    }
  }

  async function create(e: React.FormEvent) {
    e.preventDefault();
    try {
      setLoading(true);
      await api.post("/v1/admin/ad-placements", { key, title, description, priority: Number(priority) });
      setKey(""); setTitle(""); setDescription(""); setPriority("0");
      await load();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  async function toggle(id: string, active: boolean) {
    await api.patch(`/v1/admin/ad-placements/${id}`, { active });
    await load();
  }

  useEffect(() => { load(); }, []);

  return (
    <AdminGuard>
      <main className="p-6 space-y-6">
        <h1 className="text-xl font-semibold">Ad Placements</h1>
        <form onSubmit={create} className="flex flex-wrap gap-2">
          <input value={key} onChange={e => setKey(e.target.value)} placeholder="Key" className="border px-3 py-2 rounded" />
          <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Title" className="border px-3 py-2 rounded" />
          <input value={description} onChange={e => setDescription(e.target.value)} placeholder="Description" className="border px-3 py-2 rounded w-72" />
          <input value={priority} onChange={e => setPriority(e.target.value)} placeholder="Priority" className="border px-3 py-2 rounded w-24" />
          <button disabled={loading || !key || !title} className="bg-blue-600 text-white px-4 py-2 rounded">Create</button>
        </form>
        {error && <p className="text-red-600">{error}</p>}
        <div className="overflow-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="text-left">
                <th className="py-2">Key</th>
                <th>Title</th>
                <th>Description</th>
                <th>Priority</th>
                <th>Active</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr key={item.id} className="border-t">
                  <td className="py-2">{item.key}</td>
                  <td>{item.title}</td>
                  <td>{item.description}</td>
                  <td>{item.priority}</td>
                  <td>
                    <button className="text-blue-600" onClick={() => toggle(item.id, !item.active)}>
                      {String(item.active)}
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
