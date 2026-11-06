"use client";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import PageHeader from "@/app/components/page-header";
import Table, { Column } from "@/app/components/ui/table";
import useUrlState from "@/app/hooks/useUrlState";
import useDebounce from "@/app/hooks/useDebounce";

interface TxItem {
  id: string;
  type: string;
  status: string;
  amount: string | number;
  user?: { email?: string; profile?: { displayName?: string } };
  createdAt: string;
}

export default function WalletPage() {
  const [urlState, setUrlState] = useUrlState({ page: 1, size: 20, q: "", sort: "createdAt", dir: "desc" });
  const [qLocal, setQLocal] = useState<string>((urlState.q as any) || "");
  const q = useDebounce(qLocal, 400);
  const page = Number(urlState.page) || 1;
  const pageSize = Number(urlState.size) || 20;
  const sortKey = (urlState.sort as string) || "createdAt";
  const sortDir = (urlState.dir as 'asc' | 'desc') || "desc";

  const { data = { items: [], total: 0 }, isLoading, isError, refetch } = useQuery({
    queryKey: ["admin-wallet", page, pageSize, q, sortKey, sortDir],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(pageSize), sort: sortKey, dir: sortDir });
        if (q) params.set("query", q);
        const res = await api.get<{ items: TxItem[]; total: number }>(`/v1/admin/wallet/transactions?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: TxItem[]; total: number };
      }
    },
  });

  const columns = useMemo<Column<TxItem>[]>(
    () => [
      { key: "type", header: "Type", sortable: true },
      { key: "status", header: "Status", sortable: true },
      { key: "amount", header: "Amount", sortable: true },
      { key: "userEmail", header: "User", render: (t) => t.user?.profile?.displayName || t.user?.email || "-", sortable: true },
      { key: "createdAt", header: "Created", sortable: true },
    ],
    []
  );

  const rows = useMemo(
    () => data.items.map((t) => ({ ...t, userEmail: t.user?.email ?? "" })),
    [data]
  );

  return (
    <div className="space-y-4">
      <PageHeader
        title="Wallet"
        breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Wallet" }]}
        actions={
          <div className="flex items-center gap-2">
            <input
              value={qLocal}
              onChange={(e) => setQLocal(e.target.value)}
              onBlur={() => setUrlState({ q: qLocal, page: 1 })}
              placeholder="Search transactions…"
              className="px-3 py-2 text-sm rounded border focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <button className="px-3 py-2 text-sm rounded border" onClick={() => refetch()}>Refresh</button>
            <a href="/wallet/credit" className="px-3 py-2 text-sm rounded border bg-indigo-600 text-white">Credit Wallet</a>
            <a href="/wallet/withdrawals" className="px-3 py-2 text-sm rounded border">Withdrawals</a>
            <a href="/wallet/audit" className="px-3 py-2 text-sm rounded border">Audit</a>
            <a href="/wallet/analytics" className="px-3 py-2 text-sm rounded border">Analytics</a>
          </div>
        }
      />
      <Table
        columns={columns}
        data={rows as any}
        loading={isLoading}
        error={isError && "Failed to load transactions"}
        emptyLabel="No transactions found"
        pagination={{
          page,
          pageSize,
          total: data.total,
          onPageChange: (p) => setUrlState({ page: p }),
          onPageSizeChange: (s) => setUrlState({ size: s, page: 1 }),
        }}
        sortKey={sortKey}
        sortDir={sortDir}
        onSortChange={(key, d) => setUrlState({ sort: key, dir: d })}
      />
    </div>
  );
}
