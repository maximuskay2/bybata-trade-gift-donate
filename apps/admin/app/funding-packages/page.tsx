"use client";
import React, { useEffect, useState } from "react";
import { api } from "@/lib/api";
import AdminGuard from "@/app/components/admin-guard";
import { useToast } from "@/app/components/ui/use-toast";

export default function FundingPackagesPage() {
  const [packages, setPackages] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { toast } = useToast();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState({
    name: "",
    description: "",
    price: "",
    currency: "USD",
    bonusPercentage: "0",
    isPopular: false,
    sortOrder: "0",
    active: true,
  });

  async function fetchPackages() {
    try {
      setError(null);
      const res = await api.get("/v1/admin/funding-packages");
      setPackages(res.data ?? []);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    }
  }

  async function createPackage(e: React.FormEvent) {
    e.preventDefault();
    try {
      setLoading(true);
      const price = parseFloat(form.price);
      if (!form.name || isNaN(price) || price <= 0) {
        setError("Name and valid price are required");
        setLoading(false);
        return;
      }
      await api.post("/v1/admin/funding-packages", {
        name: form.name,
        description: form.description || undefined,
        price,
        currency: form.currency,
        bonusPercentage: parseFloat(form.bonusPercentage) || 0,
        isPopular: form.isPopular,
        sortOrder: parseInt(form.sortOrder, 10) || 0,
        active: form.active,
      });
      toast({ title: "Package created" });
      setForm({ name: "", description: "", price: "", currency: "USD", bonusPercentage: "0", isPopular: false, sortOrder: "0", active: true });
      await fetchPackages();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  async function updatePackage(id: string) {
    try {
      setLoading(true);
      const price = parseFloat(form.price);
      await api.patch(`/v1/admin/funding-packages/${id}`, {
        name: form.name,
        description: form.description || undefined,
        price: isNaN(price) ? undefined : price,
        currency: form.currency,
        bonusPercentage: parseFloat(form.bonusPercentage) || 0,
        isPopular: form.isPopular,
        sortOrder: parseInt(form.sortOrder, 10) || 0,
        active: form.active,
      });
      toast({ title: "Package updated" });
      setEditingId(null);
      setForm({ name: "", description: "", price: "", currency: "USD", bonusPercentage: "0", isPopular: false, sortOrder: "0", active: true });
      await fetchPackages();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  async function deletePackage(id: string) {
    if (!confirm("Delete this package?")) return;
    try {
      setLoading(true);
      await api.delete(`/v1/admin/funding-packages/${id}`);
      toast({ title: "Package deleted" });
      await fetchPackages();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  function startEdit(pkg: any) {
    setEditingId(pkg.id);
    setForm({
      name: pkg.name,
      description: pkg.description ?? "",
      price: String(pkg.price),
      currency: pkg.currency ?? "USD",
      bonusPercentage: String(pkg.bonusPercentage ?? 0),
      isPopular: pkg.isPopular ?? false,
      sortOrder: String(pkg.sortOrder ?? 0),
      active: pkg.active ?? true,
    });
  }

  useEffect(() => {
    fetchPackages();
  }, []);

  return (
    <AdminGuard>
      <main className="p-6">
        <h1 className="text-xl font-semibold mb-4">Funding Packages</h1>
        <p className="text-sm text-gray-600 mb-4">
          Configure packages shown on the fund wallet screen. BYC amounts are calculated from exchange rates at /rates.
        </p>

        <form onSubmit={editingId ? (e) => { e.preventDefault(); updatePackage(editingId); } : createPackage} className="mb-6 p-4 border rounded-lg bg-gray-50">
          <h2 className="font-medium mb-3">{editingId ? "Edit Package" : "Add Package"}</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
            <div>
              <label className="block text-sm mb-1">Name</label>
              <input
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="Starter Pack"
                className="border px-3 py-2 rounded w-full"
                required
              />
            </div>
            <div>
              <label className="block text-sm mb-1">Price</label>
              <input
                type="number"
                step="0.01"
                value={form.price}
                onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))}
                placeholder="10.00"
                className="border px-3 py-2 rounded w-full"
              />
            </div>
            <div>
              <label className="block text-sm mb-1">Currency</label>
              <select
                value={form.currency}
                onChange={(e) => setForm((f) => ({ ...f, currency: e.target.value }))}
                className="border px-3 py-2 rounded w-full"
              >
                <option value="USD">USD</option>
                <option value="NGN">NGN</option>
              </select>
            </div>
            <div>
              <label className="block text-sm mb-1">Bonus %</label>
              <input
                type="number"
                step="0.1"
                value={form.bonusPercentage}
                onChange={(e) => setForm((f) => ({ ...f, bonusPercentage: e.target.value }))}
                placeholder="10"
                className="border px-3 py-2 rounded w-full"
              />
            </div>
            <div className="md:col-span-2">
              <label className="block text-sm mb-1">Description</label>
              <input
                value={form.description}
                onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                placeholder="Perfect for getting started"
                className="border px-3 py-2 rounded w-full"
              />
            </div>
            <div>
              <label className="block text-sm mb-1">Sort Order</label>
              <input
                type="number"
                value={form.sortOrder}
                onChange={(e) => setForm((f) => ({ ...f, sortOrder: e.target.value }))}
                className="border px-3 py-2 rounded w-full"
              />
            </div>
            <div className="flex items-center gap-4">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={form.isPopular}
                  onChange={(e) => setForm((f) => ({ ...f, isPopular: e.target.checked }))}
                />
                <span className="text-sm">Popular</span>
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={form.active}
                  onChange={(e) => setForm((f) => ({ ...f, active: e.target.checked }))}
                />
                <span className="text-sm">Active</span>
              </label>
            </div>
          </div>
          <div className="mt-3 flex gap-2">
            <button type="submit" disabled={loading} className="bg-blue-600 text-white px-4 py-2 rounded disabled:opacity-50">
              {editingId ? "Update" : "Create"}
            </button>
            {editingId && (
              <button
                type="button"
                onClick={() => { setEditingId(null); setForm({ name: "", description: "", price: "", currency: "USD", bonusPercentage: "0", isPopular: false, sortOrder: "0", active: true }); }}
                className="border px-4 py-2 rounded"
              >
                Cancel
              </button>
            )}
          </div>
        </form>

        {error && <p className="text-red-600 mb-4">{error}</p>}

        <div className="border rounded overflow-hidden">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-100">
              <tr>
                <th className="text-left p-3">Name</th>
                <th className="text-left p-3">Price</th>
                <th className="text-left p-3">Bonus %</th>
                <th className="text-left p-3">Popular</th>
                <th className="text-left p-3">Active</th>
                <th className="text-left p-3">Order</th>
                <th className="text-right p-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {packages.map((pkg) => (
                <tr key={pkg.id} className="border-t">
                  <td className="p-3 font-medium">{pkg.name}</td>
                  <td className="p-3">{pkg.price} {pkg.currency}</td>
                  <td className="p-3">{pkg.bonusPercentage}%</td>
                  <td className="p-3">{pkg.isPopular ? "Yes" : "No"}</td>
                  <td className="p-3">{pkg.active ? "Yes" : "No"}</td>
                  <td className="p-3">{pkg.sortOrder}</td>
                  <td className="p-3 text-right">
                    <button onClick={() => startEdit(pkg)} className="text-blue-600 mr-2">Edit</button>
                    <button onClick={() => deletePackage(pkg.id)} className="text-red-600">Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {packages.length === 0 && (
            <p className="p-4 text-gray-500 text-center">No packages yet. Create one above.</p>
          )}
        </div>
      </main>
    </AdminGuard>
  );
}
