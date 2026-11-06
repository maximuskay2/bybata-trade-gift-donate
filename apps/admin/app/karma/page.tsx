"use client";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import PageHeader from "@/app/components/page-header";
import Table, { Column } from "@/app/components/ui/table";
import useUrlState from "@/app/hooks/useUrlState";
import useDebounce from "@/app/hooks/useDebounce";

interface KarmaTransaction {
  id: string;
  userId: string;
  user?: { email?: string; profile?: { displayName?: string } };
  action: string;
  points: number;
  reason: string;
  metadata?: Record<string, any>;
  createdAt: string;
}

interface KarmaLeaderboard {
  userId: string;
  user?: { email?: string; profile?: { displayName?: string } };
  totalKarma: number;
  level: string;
  rank: number;
}

interface KarmaStats {
  totalTransactions: number;
  totalPointsAwarded: number;
  totalPointsDeducted: number;
  averageUserKarma: number;
  topLevel: string;
  activeUsers: number;
  actionBreakdown: Record<string, number>;
  levelDistribution: Record<string, number>;
}

export default function KarmaPage() {
  const [urlState, setUrlState] = useUrlState({ page: 1, size: 20, q: "", sort: "createdAt", dir: "desc" });
  const [qLocal, setQLocal] = useState<string>((urlState.q as any) || "");
  const q = useDebounce(qLocal, 400);
  const [selectedAction, setSelectedAction] = useState<string>("all");
  const [activeTab, setActiveTab] = useState<"transactions" | "leaderboard">("transactions");

  const page = Number(urlState.page) || 1;
  const pageSize = Number(urlState.size) || 20;
  const sortKey = (urlState.sort as string) || "createdAt";
  const sortDir = (urlState.dir as 'asc' | 'desc') || "desc";

  const { data: stats } = useQuery({
    queryKey: ["admin-karma-stats"],
    queryFn: async () => {
      try {
        const res = await api.get<KarmaStats>(`/v1/admin/karma/stats`);
        return res.data;
      } catch {
        return null;
      }
    },
  });

  const { data: transactions = { items: [], total: 0 }, isLoading: transactionsLoading, isError: transactionsError, refetch: refetchTransactions } = useQuery({
    queryKey: ["admin-karma-transactions", page, pageSize, q, sortKey, sortDir, selectedAction],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(pageSize), sort: sortKey, dir: sortDir });
        if (q) params.set("query", q);
        if (selectedAction !== "all") params.set("action", selectedAction);
        const res = await api.get<{ items: KarmaTransaction[]; total: number }>(`/v1/admin/karma/transactions?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: KarmaTransaction[]; total: number };
      }
    },
    enabled: activeTab === "transactions",
  });

  const { data: leaderboard = { items: [], total: 0 }, isLoading: leaderboardLoading, isError: leaderboardError, refetch: refetchLeaderboard } = useQuery({
    queryKey: ["admin-karma-leaderboard", page, pageSize, q],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(pageSize) });
        if (q) params.set("query", q);
        const res = await api.get<{ items: KarmaLeaderboard[]; total: number }>(`/v1/admin/karma/leaderboard?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: KarmaLeaderboard[]; total: number };
      }
    },
    enabled: activeTab === "leaderboard",
  });

  const transactionColumns = useMemo<Column<KarmaTransaction>[]>(
    () => [
      { key: "userEmail", header: "User", render: (t) => t.user?.profile?.displayName || t.user?.email || "-", sortable: true },
      { key: "action", header: "Action", sortable: true },
      { 
        key: "points", 
        header: "Points", 
        sortable: true,
        render: (transaction) => (
          <span className={`font-medium ${transaction.points > 0 ? 'text-green-600' : 'text-red-600'}`}>
            {transaction.points > 0 ? '+' : ''}{transaction.points}
          </span>
        )
      },
      { key: "reason", header: "Reason", sortable: false },
      { 
        key: "createdAt", 
        header: "Date", 
        sortable: true,
        render: (transaction) => new Date(transaction.createdAt).toLocaleDateString()
      },
    ],
    []
  );

  const leaderboardColumns = useMemo<Column<KarmaLeaderboard>[]>(
    () => [
      { 
        key: "rank", 
        header: "Rank", 
        sortable: false,
        render: (entry) => `#${entry.rank}`
      },
      { key: "userEmail", header: "User", render: (e) => e.user?.profile?.displayName || e.user?.email || "-", sortable: true },
      { 
        key: "totalKarma", 
        header: "Total Karma", 
        sortable: true,
        render: (entry) => (
          <span className="font-medium text-purple-600">
            {entry.totalKarma.toLocaleString()}
          </span>
        )
      },
      { 
        key: "level", 
        header: "Level", 
        sortable: true,
        render: (entry) => (
          <span className={`px-2 py-1 rounded text-xs font-medium ${
            entry.level === 'LEGEND' ? 'bg-purple-100 text-purple-800' :
            entry.level === 'HERO' ? 'bg-blue-100 text-blue-800' :
            entry.level === 'CHAMPION' ? 'bg-green-100 text-green-800' :
            entry.level === 'CONTRIBUTOR' ? 'bg-yellow-100 text-yellow-800' :
            entry.level === 'HELPER' ? 'bg-orange-100 text-orange-800' :
            'bg-gray-100 text-gray-800'
          }`}>
            {entry.level.toLowerCase()}
          </span>
        )
      },
    ],
    []
  );

  const transactionRows = useMemo(
    () => transactions.items.map((t) => ({ ...t, userEmail: t.user?.email ?? "" })),
    [transactions]
  );

  const leaderboardRows = useMemo(
    () => leaderboard.items.map((e) => ({ ...e, userEmail: e.user?.email ?? "" })),
    [leaderboard]
  );

  const actionOptions = [
    { value: "all", label: "All Actions" },
    { value: "TRADE_COMPLETE", label: "Trade Complete" },
    { value: "GIFT_GIVEN", label: "Gift Given" },
    { value: "DONATION_MADE", label: "Donation Made" },
    { value: "COMMUNITY_POST", label: "Community Post" },
    { value: "COMMUNITY_HELP", label: "Community Help" },
    { value: "VERIFICATION_BONUS", label: "Verification Bonus" },
  ];

  const currentData = activeTab === "transactions" ? transactions : leaderboard;
  const currentLoading = activeTab === "transactions" ? transactionsLoading : leaderboardLoading;
  const currentError = activeTab === "transactions" ? transactionsError : leaderboardError;
  const currentRefetch = activeTab === "transactions" ? refetchTransactions : refetchLeaderboard;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Karma System"
        breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Karma System" }]}
        actions={
          <div className="flex items-center gap-2">
            {activeTab === "transactions" && (
              <select
                value={selectedAction}
                onChange={(e) => setSelectedAction(e.target.value)}
                className="px-3 py-2 text-sm rounded border focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                {actionOptions.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            )}
            <input
              value={qLocal}
              onChange={(e) => setQLocal(e.target.value)}
              onBlur={() => setUrlState({ q: qLocal, page: 1 })}
              placeholder="Search users…"
              className="px-3 py-2 text-sm rounded border focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <button className="px-3 py-2 text-sm rounded border" onClick={currentRefetch}>
              Refresh
            </button>
          </div>
        }
      />

      {/* Stats Cards */}
      {stats && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-4">
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-gray-900">{stats.totalTransactions.toLocaleString()}</div>
            <div className="text-sm text-gray-500">Transactions</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-green-600">+{stats.totalPointsAwarded.toLocaleString()}</div>
            <div className="text-sm text-gray-500">Points Awarded</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-red-600">-{Math.abs(stats.totalPointsDeducted).toLocaleString()}</div>
            <div className="text-sm text-gray-500">Points Deducted</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-purple-600">{stats.averageUserKarma.toFixed(0)}</div>
            <div className="text-sm text-gray-500">Avg User Karma</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-blue-600">{stats.topLevel}</div>
            <div className="text-sm text-gray-500">Top Level</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-indigo-600">{stats.activeUsers.toLocaleString()}</div>
            <div className="text-sm text-gray-500">Active Users</div>
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="bg-white rounded-lg shadow border">
        <div className="border-b">
          <nav className="flex space-x-8 px-6">
            <button
              onClick={() => setActiveTab("transactions")}
              className={`py-4 px-1 border-b-2 font-medium text-sm ${
                activeTab === "transactions"
                  ? "border-indigo-500 text-indigo-600"
                  : "border-transparent text-gray-500 hover:text-gray-700"
              }`}
            >
              Transactions
            </button>
            <button
              onClick={() => setActiveTab("leaderboard")}
              className={`py-4 px-1 border-b-2 font-medium text-sm ${
                activeTab === "leaderboard"
                  ? "border-indigo-500 text-indigo-600"
                  : "border-transparent text-gray-500 hover:text-gray-700"
              }`}
            >
              Leaderboard
            </button>
          </nav>
        </div>

        <div className="p-6">
          <Table
            columns={activeTab === "transactions" ? transactionColumns : leaderboardColumns}
            data={activeTab === "transactions" ? transactionRows as any : leaderboardRows as any}
            loading={currentLoading}
            error={currentError && `Failed to load ${activeTab}`}
            emptyLabel={`No ${activeTab} found`}
            pagination={{
              page,
              pageSize,
              total: currentData.total,
              onPageChange: (p) => setUrlState({ page: p }),
              onPageSizeChange: (s) => setUrlState({ size: s, page: 1 }),
            }}
            sortKey={sortKey}
            sortDir={sortDir}
            onSortChange={(key, d) => setUrlState({ sort: key, dir: d })}
          />
        </div>
      </div>
    </div>
  );
}