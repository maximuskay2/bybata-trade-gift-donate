"use client";

import dynamic from "next/dynamic";
import { useMemo, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { DataItem } from "react-svg-worldmap";
import { MapPin } from "lucide-react";

const WorldMap = dynamic(() => import("react-svg-worldmap"), { ssr: false });

export type LocationStat = {
  label: string;
  count: number;
  countryCode?: string;
};

export type CountryStat = {
  countryCode: string;
  label: string;
  count: number;
};

export type LocationStatsResponse = {
  totalWithLocation: number;
  totalProfiles: number;
  locations: LocationStat[];
  byCountry: CountryStat[];
};

type ViewMode = "map" | "bar" | "pie";

const CHART_COLORS = [
  "#6366f1",
  "#8b5cf6",
  "#a855f7",
  "#ec4899",
  "#f97316",
  "#22c55e",
  "#14b8a6",
  "#06b6d4",
  "#eab308",
  "#f43f5e",
];

export function UserLocationsPanel({
  data,
  loading,
}: {
  data?: LocationStatsResponse;
  loading: boolean;
}) {
  const [view, setView] = useState<ViewMode>("map");

  const barData = useMemo(
    () =>
      (data?.locations ?? []).map((item) => ({
        name: item.label,
        users: item.count,
      })),
    [data?.locations],
  );

  const pieData = useMemo(() => {
    const items = data?.locations ?? [];
    if (items.length <= 8) {
      return items.map((item) => ({ name: item.label, value: item.count }));
    }
    const top = items.slice(0, 7);
    const otherCount = items.slice(7).reduce((sum, item) => sum + item.count, 0);
    return [
      ...top.map((item) => ({ name: item.label, value: item.count })),
      { name: "Other", value: otherCount },
    ];
  }, [data?.locations]);

  const mapData = useMemo(
    () =>
      (data?.byCountry ?? []).map(
        (item): DataItem<number> => ({
          country: item.countryCode.toLowerCase() as DataItem<number>["country"],
          value: item.count,
        }),
      ),
    [data?.byCountry],
  );

  const hasData = Boolean(data?.locations.length);

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between mb-6">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <MapPin className="w-5 h-5 text-indigo-600" />
            <h3 className="font-semibold text-gray-900">User Locations</h3>
          </div>
          <p className="text-sm text-gray-500">
            Where users are based — map, bar chart, or distribution view
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="text-right">
            <p className="text-2xl font-bold text-gray-900">
              {loading ? "..." : (data?.totalWithLocation ?? 0).toLocaleString()}
            </p>
            <p className="text-xs text-gray-500">users with location</p>
          </div>

          <div className="inline-flex rounded-lg border border-gray-200 bg-gray-50 p-1">
            {(
              [
                ["map", "Map"],
                ["bar", "Bar"],
                ["pie", "Pie"],
              ] as const
            ).map(([mode, label]) => (
              <button
                key={mode}
                type="button"
                onClick={() => setView(mode)}
                className={`px-3 py-1.5 text-xs font-semibold rounded-md transition ${
                  view === mode
                    ? "bg-white text-indigo-700 shadow-sm"
                    : "text-gray-600 hover:text-gray-900"
                }`}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {loading ? (
        <div className="h-[360px] rounded-xl bg-gray-100 animate-pulse" />
      ) : !hasData ? (
        <div className="rounded-lg border border-dashed border-gray-200 px-4 py-16 text-center text-sm text-gray-500">
          No user location data yet. Locations appear when users add a profile
          location or country during signup.
        </div>
      ) : (
        <div className="min-h-[360px]">
          {view === "map" && (
            <div className="space-y-4">
              {mapData.length > 0 ? (
                <>
                  <div className="flex justify-center overflow-x-auto">
                    <WorldMap
                      color="#6366f1"
                      size="responsive"
                      data={mapData}
                      valueSuffix=" users"
                      strokeOpacity={0.25}
                      backgroundColor="#f8fafc"
                      tooltipBgColor="#111827"
                      tooltipTextColor="#f9fafb"
                    />
                  </div>
                  <div className="flex flex-wrap gap-2 justify-center">
                    {data?.byCountry.slice(0, 8).map((item, index) => (
                      <span
                        key={item.countryCode}
                        className="inline-flex items-center gap-2 rounded-full bg-gray-100 px-3 py-1 text-xs font-medium text-gray-700"
                      >
                        <span
                          className="h-2 w-2 rounded-full"
                          style={{
                            backgroundColor:
                              CHART_COLORS[index % CHART_COLORS.length],
                          }}
                        />
                        {item.label}: {item.count}
                      </span>
                    ))}
                  </div>
                </>
              ) : (
                <div className="rounded-lg border border-dashed border-gray-200 px-4 py-16 text-center text-sm text-gray-500">
                  No country codes available for the map yet. Switch to Bar or Pie
                  to see location labels from profile text.
                </div>
              )}
            </div>
          )}

          {view === "bar" && (
            <ResponsiveContainer width="100%" height={360}>
              <BarChart
                data={barData}
                layout="vertical"
                margin={{ top: 8, right: 16, left: 8, bottom: 8 }}
              >
                <CartesianGrid strokeDasharray="3 3" horizontal={false} />
                <XAxis type="number" allowDecimals={false} />
                <YAxis
                  type="category"
                  dataKey="name"
                  width={120}
                  tick={{ fontSize: 12 }}
                />
                <Tooltip
                  formatter={(value) =>
                    `${Number(value ?? 0).toLocaleString()} users`
                  }
                  contentStyle={{
                    borderRadius: 12,
                    borderColor: "#e5e7eb",
                  }}
                />
                <Bar dataKey="users" radius={[0, 8, 8, 0]}>
                  {barData.map((_, index) => (
                    <Cell
                      key={`bar-${index}`}
                      fill={CHART_COLORS[index % CHART_COLORS.length]}
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}

          {view === "pie" && (
            <ResponsiveContainer width="100%" height={360}>
              <PieChart>
                <Pie
                  data={pieData}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  innerRadius={70}
                  outerRadius={120}
                  paddingAngle={2}
                  label={({ name, percent }) =>
                    `${name} ${((percent ?? 0) * 100).toFixed(0)}%`
                  }
                >
                  {pieData.map((_, index) => (
                    <Cell
                      key={`pie-${index}`}
                      fill={CHART_COLORS[index % CHART_COLORS.length]}
                    />
                  ))}
                </Pie>
                <Tooltip
                  formatter={(value, name) =>
                    `${name}: ${Number(value ?? 0).toLocaleString()} users`
                  }
                  contentStyle={{
                    borderRadius: 12,
                    borderColor: "#e5e7eb",
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          )}
        </div>
      )}
    </div>
  );
}
