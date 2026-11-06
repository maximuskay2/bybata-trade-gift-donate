"use client";
import React, { useEffect, useState } from "react";
import { api } from "@/lib/api";
import AdminGuard from "@/app/components/admin-guard";

export default function BoostTypesPage() {
  const [items, setItems] = useState<any[]>([]);
  const [slug, setSlug] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try {
      setError(null);
      const res = await api.get("/v1/admin/boost-types");
      setItems(res.data);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    }
  }

  async function create(e: React.FormEvent) {
    e.preventDefault();
    try {
      setLoading(true);
      await api.post("/v1/admin/boost-types", { slug, title, description });
      setSlug(""); setTitle(""); setDescription("");
      await load();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  async function toggle(id: string, active: boolean) {
    await api.patch(`/v1/admin/boost-types/${id}`, { active });
    await load();
  }

  useEffect(() => { load(); }, []);

  return (
    <AdminGuard>
      <main className="p-6 space-y-6">
        <h1 className="text-xl font-semibold">Boost Types</h1>
        <form onSubmit={create} className="flex flex-wrap gap-2">
          <input value={slug} onChange={e => setSlug(e.target.value)} placeholder="Slug" className="border px-3 py-2 rounded" />
          <input value={title} onChange={e => setTitle(e.target.value)} placeholder="Title" className="border px-3 py-2 rounded" />
          <input value={description} onChange={e => setDescription(e.target.value)} placeholder="Description" className="border px-3 py-2 rounded w-72" />
          <button disabled={loading || !slug || !title} className="bg-blue-600 text-white px-4 py-2 rounded">Create</button>
        </form>
        {error && <p className="text-red-600">{error}</p>}
        <div className="overflow-auto rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-200 bg-gradient-to-r from-gray-50 to-gray-50 text-left text-gray-700 font-semibold">
                <th className="px-6 py-4">Slug</th>
                <th className="px-6 py-4">Title</th>
                <th className="px-6 py-4">Description</th>
                <th className="px-6 py-4">Active</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {items.map((item) => (
                <tr key={item.id} className="hover:bg-gray-50 transition-all duration-200">
                  <td className="px-6 py-4 text-gray-900">{item.slug}</td>
                  <td className="px-6 py-4 text-gray-700">{item.title}</td>
                  <td className="px-6 py-4 text-gray-700">{item.description}</td>
                  <td className="px-6 py-4">
                    <button
                      className="text-blue-600 hover:text-blue-700 hover:bg-blue-50 px-3 py-1 rounded-lg transition-colors"
                      onClick={() => toggle(item.id, !item.active)}
                    >
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
