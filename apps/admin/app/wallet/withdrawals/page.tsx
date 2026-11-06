"use client";
import { useEffect, useMemo, useState } from "react";
import AdminGuard from "@/app/components/admin-guard";
import { api } from "@/lib/api";
import PageHeader from "@/app/components/page-header";

interface WithdrawalItem {
  id: string;
  userId: string;
  amount: string | number;
  currency: string;
  status: string;
  createdAt: string;
  completedAt?: string | null;
  memo?: string | null;
  user?: { email?: string; profile?: { displayName?: string } };
  destination?: {
    bankDetails?: {
      bankName?: string;
      accountHolderName?: string;
      accountNumber?: string;
      accountType?: string;
    };
    walletSource?: string;
    currency?: string;
    fee?: number;
    netAmount?: number;
    conversionRate?: number;
    convertedAmount?: number;
  };
}

export default function WalletWithdrawalsPage() {
  const [items, setItems] = useState<WithdrawalItem[]>([]);
  const [status, setStatus] = useState<string>("PENDING");
  const [userId, setUserId] = useState<string>("");
  const [page, setPage] = useState<number>(1);
  const [pageSize, setPageSize] = useState<number>(20);
  const [total, setTotal] = useState<number>(0);
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [references, setReferences] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchItems = async () => {
    try {
      setError(null);
      const params: Record<string, string | number> = {
        page,
        size: pageSize,
      };
      if (status) params.status = status;
      if (userId.trim()) params.userId = userId.trim();
      const res = await api.get("/v1/admin/wallet/withdrawals", { params });
      setItems(res.data?.items ?? []);
      setTotal(res.data?.total ?? 0);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    }
  };

  useEffect(() => {
    fetchItems();
  }, [status, userId, page, pageSize]);

  const onComplete = async (id: string) => {
    const reference = references[id]?.trim() || undefined;
    try {
      setLoading(true);
      await api.post(`/v1/admin/wallet/withdrawals/${id}/complete`, { reference });
      await fetchItems();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  };

  const onReject = async (id: string) => {
    const reason = reasons[id]?.trim() || undefined;
    try {
      setLoading(true);
      await api.post(`/v1/admin/wallet/withdrawals/${id}/reject`, { reason });
      await fetchItems();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  };

  const onFail = async (id: string) => {
    const reason = reasons[id]?.trim() || undefined;
    try {
      setLoading(true);
      await api.post(`/v1/admin/wallet/withdrawals/${id}/fail`, { reason });
      await fetchItems();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  };

  const rows = useMemo(() => items, [items]);
  const totalPages = Math.max(Math.ceil(total / pageSize), 1);

  return (
    <AdminGuard>
      <div className="space-y-4">
        <PageHeader
          title="Withdrawals"
          breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Wallet", href: "/wallet" }, { label: "Withdrawals" }]}
          actions={
            <div className="flex items-center gap-2">
              <input
                className="px-3 py-2 text-sm rounded border"
                placeholder="User ID"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
              />
              <select
                className="px-3 py-2 text-sm rounded border"
                value={status}
                onChange={(e) => setStatus(e.target.value)}
              >
                <option value="">All</option>
                <option value="PENDING">Pending</option>
                <option value="COMPLETED">Completed</option>
                <option value="REJECTED">Rejected</option>
                <option value="FAILED">Failed</option>
                <option value="CANCELLED">Cancelled</option>
              </select>
              <select
                className="px-3 py-2 text-sm rounded border"
                value={pageSize}
                onChange={(e) => {
                  setPageSize(Number(e.target.value));
                  setPage(1);
                }}
              >
                <option value={10}>10</option>
                <option value={20}>20</option>
                <option value={50}>50</option>
              </select>
              <button className="px-3 py-2 text-sm rounded border" onClick={() => fetchItems()}>
                Refresh
              </button>
            </div>
          }
        />
        {error && <p className="text-red-600">{error}</p>}
        <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm">
          <table className="w-full text-sm">
            <thead className="bg-gradient-to-r from-gray-50 to-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">User</th>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">Amount</th>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">Source</th>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">Currency</th>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">Fee</th>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">Bank Details</th>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">Status</th>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">Created</th>
                <th className="text-left py-4 px-6 text-gray-700 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {rows.map((w) => (
                <tr key={w.id} className="hover:bg-gray-50 transition-all duration-200">
                  <td className="py-4 px-6 text-gray-900">
                    <div className="font-medium">{w.user?.profile?.displayName || w.user?.email || w.userId}</div>
                    <div className="text-xs text-gray-500">{w.user?.email}</div>
                  </td>
                  <td className="py-4 px-6 text-gray-700">
                    <div className="font-medium">{w.amount} BYC</div>
                    {w.destination?.convertedAmount && (
                      <div className="text-xs text-gray-500">
                        ≈ {w.destination.convertedAmount.toFixed(2)} {w.destination.currency}
                      </div>
                    )}
                  </td>
                  <td className="py-4 px-6">
                    <span className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${
                      w.destination?.walletSource === 'donation' 
                        ? 'bg-blue-100 text-blue-800' 
                        : 'bg-gray-100 text-gray-800'
                    }`}>
                      {w.destination?.walletSource === 'donation' ? 'Donation' : 'Main'}
                    </span>
                  </td>
                  <td className="py-4 px-6 text-gray-700">{w.destination?.currency || w.currency}</td>
                  <td className="py-4 px-6">
                    <div className="text-sm">
                      <div className="font-medium text-red-600">{w.destination?.fee?.toFixed(2) || '-'} BYC</div>
                      {w.destination?.fee && (
                        <div className="text-xs text-gray-500">
                          {w.destination.walletSource === 'donation' ? '10%' : 'flat'}
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="py-4 px-6 text-sm">
                    {w.destination?.bankDetails ? (
                      <div className="space-y-1">
                        <div className="font-medium">{w.destination.bankDetails.bankName}</div>
                        <div className="text-xs text-gray-600">
                          {w.destination.bankDetails.accountHolderName}
                        </div>
                        <div className="text-xs text-gray-500">
                          {w.destination.bankDetails.accountNumber}
                        </div>
                      </div>
                    ) : (
                      <span className="text-gray-400">No bank details</span>
                    )}
                  </td>
                  <td className="py-4 px-6">
                    <span className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${
                      w.status === 'COMPLETED' ? 'bg-green-100 text-green-800' :
                      w.status === 'PENDING' ? 'bg-yellow-100 text-yellow-800' :
                      w.status === 'REJECTED' ? 'bg-red-100 text-red-800' :
                      w.status === 'FAILED' ? 'bg-red-100 text-red-800' :
                      'bg-gray-100 text-gray-800'
                    }`}>
                      {w.status}
                    </span>
                  </td>
                  <td className="py-4 px-6 text-gray-700 whitespace-nowrap">
                    {new Date(w.createdAt).toLocaleString()}
                  </td>
                  <td className="py-4 px-6">
                    {w.status === "PENDING" && (
                      <div className="flex flex-col gap-2">
                        <input
                          className="px-2 py-1 text-xs rounded border"
                          placeholder="Reference (approve)"
                          value={references[w.id] ?? ""}
                          onChange={(e) => setReferences((prev) => ({ ...prev, [w.id]: e.target.value }))}
                        />
                        <input
                          className="px-2 py-1 text-xs rounded border"
                          placeholder="Reason (reject/fail)"
                          value={reasons[w.id] ?? ""}
                          onChange={(e) => setReasons((prev) => ({ ...prev, [w.id]: e.target.value }))}
                        />
                        <div className="flex gap-2 flex-wrap">
                          <button disabled={loading} onClick={() => onComplete(w.id)} className="text-green-600 hover:bg-green-50 px-2 py-1 rounded text-xs transition-colors font-medium">
                            Approve
                          </button>
                          <button disabled={loading} onClick={() => onReject(w.id)} className="text-red-600 hover:bg-red-50 px-2 py-1 rounded text-xs transition-colors font-medium">
                            Reject
                          </button>
                          <button disabled={loading} onClick={() => onFail(w.id)} className="text-orange-600 hover:bg-orange-50 px-2 py-1 rounded text-xs transition-colors font-medium">
                            Fail
                          </button>
                        </div>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
              {rows.length === 0 && (
                <tr>
                  <td colSpan={9} className="py-8 text-gray-500 text-center">
                    <div className="flex flex-col items-center gap-2">
                      <div className="text-4xl opacity-20">📭</div>
                      <p>No withdrawals found.</p>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between">
          <div className="text-sm text-gray-500">
            Page {page} of {totalPages} • {total} total
          </div>
          <div className="flex items-center gap-2">
            <button
              className="px-3 py-2 text-sm rounded border"
              disabled={page <= 1}
              onClick={() => setPage((p) => Math.max(p - 1, 1))}
            >
              Prev
            </button>
            <button
              className="px-3 py-2 text-sm rounded border"
              disabled={page >= totalPages}
              onClick={() => setPage((p) => Math.min(p + 1, totalPages))}
            >
              Next
            </button>
          </div>
        </div>
      </div>
    </AdminGuard>
  );
}
