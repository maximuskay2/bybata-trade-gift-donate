"use client";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  Users,
  TrendingUp,
  Wallet,
  Activity,
  Heart,
  Gift,
} from "lucide-react";
import {
  UserLocationsPanel,
  type LocationStatsResponse,
} from "@/app/components/user-locations-panel";

type CampaignStats = {
  activeCampaigns: number;
};

type GiftStats = {
  activeGifts: number;
};

export default function DashboardPage() {
  const usersQ = useQuery({
    queryKey: ["dash-users"],
    queryFn: async () => {
      const res = await api.get<{ items: unknown[]; total: number }>(
        `/v1/admin/users?page=1&size=1&sort=createdAt&dir=desc`,
      );
      return res.data.total;
    },
  });

  const tradesQ = useQuery({
    queryKey: ["dash-trades"],
    queryFn: async () => {
      const res = await api.get<{ items: unknown[]; total: number }>(
        `/v1/admin/trades?page=1&size=1&sort=createdAt&dir=desc`,
      );
      return res.data.total;
    },
  });

  const txQ = useQuery({
    queryKey: ["dash-tx"],
    queryFn: async () => {
      const res = await api.get<{ items: unknown[]; total: number }>(
        `/v1/admin/wallet/transactions?page=1&size=1&sort=createdAt&dir=desc`,
      );
      return res.data.total;
    },
  });

  const donationsQ = useQuery({
    queryKey: ["dash-active-donations"],
    queryFn: async () => {
      const res = await api.get<CampaignStats>(`/v1/admin/campaigns/stats`);
      return res.data.activeCampaigns;
    },
  });

  const giftsQ = useQuery({
    queryKey: ["dash-active-gifts"],
    queryFn: async () => {
      const res = await api.get<GiftStats>(`/v1/admin/gifts/stats`);
      return res.data.activeGifts;
    },
  });

  const locationsQ = useQuery({
    queryKey: ["dash-user-locations"],
    queryFn: async () => {
      const res = await api.get<LocationStatsResponse>(
        `/v1/admin/users/location-stats?limit=10`,
      );
      return res.data;
    },
  });

  return (
    <div className="space-y-8">
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-indigo-600 via-purple-600 to-pink-600 p-8 text-white shadow-2xl">
        <div className="absolute top-0 right-0 w-96 h-96 bg-white/10 rounded-full blur-3xl -mr-32 -mt-32" />
        <div className="absolute bottom-0 left-0 w-80 h-80 bg-white/5 rounded-full blur-3xl -ml-40 -mb-40" />
        <div className="relative z-10">
          <h1 className="text-4xl font-bold mb-2">Welcome back, Admin</h1>
          <p className="text-white/80">
            Here&apos;s what&apos;s happening with your platform today
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        <StatCard
          title="Total Users"
          value={num(usersQ.data)}
          loading={usersQ.isLoading}
          icon={Users}
          gradient="from-blue-500 to-cyan-500"
        />
        <StatCard
          title="Active Trades"
          value={num(tradesQ.data)}
          loading={tradesQ.isLoading}
          icon={TrendingUp}
          gradient="from-emerald-500 to-teal-500"
        />
        <StatCard
          title="Active Donations"
          value={num(donationsQ.data)}
          loading={donationsQ.isLoading}
          icon={Heart}
          gradient="from-green-500 to-emerald-600"
        />
        <StatCard
          title="Active Gifts"
          value={num(giftsQ.data)}
          loading={giftsQ.isLoading}
          icon={Gift}
          gradient="from-violet-500 to-purple-600"
        />
        <StatCard
          title="Transactions"
          value={num(txQ.data)}
          loading={txQ.isLoading}
          icon={Wallet}
          gradient="from-amber-500 to-orange-500"
        />
        <StatCard
          title="System Status"
          value="Operational"
          loading={false}
          icon={Activity}
          gradient="from-purple-500 to-pink-500"
          status="healthy"
        />
      </div>

      <UserLocationsPanel
        data={locationsQ.data}
        loading={locationsQ.isLoading}
      />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm hover:shadow-md transition-shadow">
          <h3 className="font-semibold text-gray-900 mb-2">API Endpoint</h3>
          <p className="text-sm text-gray-500 font-mono break-all">
            {process.env.NEXT_PUBLIC_API_URL}
          </p>
        </div>
        <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm hover:shadow-md transition-shadow">
          <h3 className="font-semibold text-gray-900 mb-2">Quick Actions</h3>
          <div className="flex gap-2 flex-wrap">
            <button className="px-3 py-1 text-xs font-medium bg-indigo-100 text-indigo-700 rounded-lg hover:bg-indigo-200 transition">
              View Logs
            </button>
            <button className="px-3 py-1 text-xs font-medium bg-purple-100 text-purple-700 rounded-lg hover:bg-purple-200 transition">
              System Health
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function num(n?: number) {
  return typeof n === "number" ? n.toLocaleString() : "--";
}

function StatCard({
  title,
  value,
  loading,
  icon: Icon,
  gradient,
  status,
}: {
  title: string;
  value: string | number;
  loading?: boolean;
  icon: any;
  gradient: string;
  status?: "healthy" | "warning" | "critical";
}) {
  return (
    <div className="group relative overflow-hidden rounded-xl border border-gray-200 bg-white p-6 shadow-sm hover:shadow-xl hover:border-gray-300 transition-all duration-300">
      <div
        className={`absolute inset-0 bg-gradient-to-br ${gradient} opacity-0 group-hover:opacity-5 transition-opacity duration-300`}
      />
      <div className="relative z-10">
        <div className="flex items-start justify-between mb-4">
          <div
            className={`w-12 h-12 rounded-lg bg-gradient-to-br ${gradient} p-2.5 shadow-lg`}
          >
            <Icon className="w-full h-full text-white" />
          </div>
          {status && (
            <div
              className={`w-2 h-2 rounded-full ${status === "healthy" ? "bg-green-500" : "bg-yellow-500"}`}
            />
          )}
        </div>
        <p className="text-sm font-medium text-gray-600 mb-1">{title}</p>
        <p className="text-3xl font-bold text-gray-900">
          {loading ? <span className="animate-pulse">...</span> : value}
        </p>
      </div>
    </div>
  );
}
