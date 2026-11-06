"use client";
import { useMemo, useState, type ReactNode } from "react";
import { clsx } from "clsx";
import { ChevronUp, ChevronDown, ChevronLeft, ChevronRight } from "lucide-react";

export type Column<T> = {
  key: keyof T | string;
  header: string;
  sortable?: boolean;
  className?: string;
  render?: (row: T) => ReactNode;
};

export default function Table<T extends Record<string, any>>({
  columns,
  data,
  loading,
  error,
  emptyLabel = "No data",
  search,
  searchKeys,
  onRowClick,
  pagination,
  sortKey: controlledSortKey,
  sortDir: controlledSortDir,
  onSortChange,
}: {
  columns: Column<T>[];
  data: T[];
  loading?: boolean;
  error?: string | boolean;
  emptyLabel?: string;
  search?: string;
  searchKeys?: (keyof T | string)[];
  onRowClick?: (row: T) => void;
  pagination?: {
    page: number;
    pageSize: number;
    total: number;
    onPageChange: (page: number) => void;
    onPageSizeChange?: (size: number) => void;
  };
  sortKey?: string;
  sortDir?: 'asc' | 'desc';
  onSortChange?: (key: string, dir: 'asc' | 'desc') => void;
}) {
  const [sortKey, setSortKey] = useState<string | null>(controlledSortKey ?? null);
  const [sortDir, setSortDir] = useState<"asc" | "desc">(controlledSortDir ?? "asc");

  const filtered = useMemo(() => {
    const q = (search ?? "").trim().toLowerCase();
    if (!q) return data;
    const keys = searchKeys ?? columns.map((c) => c.key);
    return data.filter((row) =>
      keys.some((k) => String(row[k as any] ?? "").toLowerCase().includes(q))
    );
  }, [data, search, searchKeys, columns]);

  const sorted = useMemo(() => {
    // If consumer provides server-side sorting handler, do not sort locally
    if (typeof onSortChange === 'function') return filtered;
    if (!sortKey) return filtered;
    const copy = [...filtered];
    copy.sort((a, b) => {
      const av = a[sortKey as any];
      const bv = b[sortKey as any];
      const sa = String(av ?? "").toLowerCase();
      const sb = String(bv ?? "").toLowerCase();
      if (sa < sb) return sortDir === "asc" ? -1 : 1;
      if (sa > sb) return sortDir === "asc" ? 1 : -1;
      return 0;
    });
    return copy;
  }, [filtered, sortKey, sortDir, onSortChange]);

  const onSort = (key: string, sortable?: boolean) => {
    if (!sortable) return;
    if (typeof onSortChange === 'function') {
      const nextDir = sortKey === key ? (sortDir === 'asc' ? 'desc' : 'asc') : 'asc';
      onSortChange(key, nextDir);
      return;
    }
    if (sortKey !== key) {
      setSortKey(key);
      setSortDir("asc");
    } else {
      setSortDir(sortDir === "asc" ? "desc" : "asc");
    }
  };

  const total = pagination?.total ?? sorted.length;
  const page = pagination?.page ?? 1;
  const pageSize = pagination?.pageSize ?? (total || 10);
  const pageCount = Math.max(1, Math.ceil(total / (pageSize || 1)));

  return (
    <div className="space-y-4">
      {/* Table Container */}
      <div className="rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm hover:shadow-md transition-shadow overflow-x-auto">
        <table className="w-full text-sm">
          {/* Table Header */}
          <thead className="bg-gradient-to-r from-gray-50 to-gray-50 border-b border-gray-200">
            <tr>
              {columns.map((c) => (
                <th
                  key={String(c.key)}
                  className={clsx(
                    "text-left px-6 py-4 font-semibold text-gray-700 transition-colors",
                    c.className,
                    c.sortable && "cursor-pointer hover:bg-gray-100 hover:text-gray-900 select-none"
                  )}
                  onClick={() => onSort(String(c.key), c.sortable)}
                  title={c.sortable ? `Click to sort by ${c.header}` : undefined}
                >
                  <div className={clsx(
                    "inline-flex items-center gap-2",
                    sortKey === c.key && "text-indigo-600 font-bold"
                  )}>
                    <span>{c.header}</span>
                    {c.sortable && (
                      <div className="opacity-0 group-hover:opacity-100 transition-opacity">
                        {sortKey === c.key ? (
                          sortDir === "asc" ? (
                            <ChevronUp size={14} className="text-indigo-600" />
                          ) : (
                            <ChevronDown size={14} className="text-indigo-600" />
                          )
                        ) : (
                          <div className="w-4 h-4 flex items-center justify-center text-gray-300">
                            <ChevronDown size={12} />
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                </th>
              ))}
            </tr>
          </thead>
          {/* Table Body */}
          <tbody className="divide-y divide-gray-200">
            {loading && (
              <tr>
                <td className="px-6 py-8 text-center text-gray-500 col-span-full" colSpan={columns.length}>
                  <div className="flex items-center justify-center">
                    <div className="animate-spin rounded-full h-6 w-6 border-2 border-indigo-500 border-t-transparent"></div>
                  </div>
                </td>
              </tr>
            )}
            {error && !loading && (
              <tr>
                <td className="px-6 py-8 text-center text-red-600 font-medium col-span-full" colSpan={columns.length}>
                  <div className="flex items-center justify-center gap-2">
                    <span className="inline-block w-2 h-2 rounded-full bg-red-600"></span>
                    {String(error)}
                  </div>
                </td>
              </tr>
            )}
            {!loading && !error && sorted.length === 0 && (
              <tr>
                <td className="px-6 py-12 text-center text-gray-500 col-span-full" colSpan={columns.length}>
                  <div className="flex flex-col items-center gap-2">
                    <div className="text-4xl opacity-20">📭</div>
                    <p>{emptyLabel}</p>
                  </div>
                </td>
              </tr>
            )}
            {!loading && !error &&
              sorted.map((row, idx) => (
                <tr
                  key={idx}
                  className={clsx(
                    "transition-all duration-200",
                    onRowClick && "hover:bg-indigo-50 cursor-pointer",
                    !onRowClick && "hover:bg-gray-50"
                  )}
                  onClick={() => onRowClick?.(row)}
                >
                  {columns.map((c) => (
                    <td
                      key={String(c.key)}
                      className={clsx(
                        "px-6 py-4 text-gray-700",
                        c.className,
                        "group"
                      )}
                    >
                      {c.render ? c.render(row) : String(row[c.key as any] ?? "-")}
                    </td>
                  ))}
                </tr>
              ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {pagination && (
        <div className="flex items-center justify-between px-6 py-4 rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm">
          <div className="flex items-center gap-2 text-sm">
            <span className="text-gray-600">
              Showing <span className="font-semibold text-gray-900">{Math.min((page - 1) * pageSize + 1, total)}</span> to{" "}
              <span className="font-semibold text-gray-900">{Math.min(page * pageSize, total)}</span> of{" "}
              <span className="font-semibold text-gray-900">{total}</span> results
            </span>
          </div>

          <div className="flex items-center gap-3">
            {/* Page Size Selector */}
            <select
              className="px-3 py-2 text-sm rounded-lg border border-gray-300 bg-white/50 backdrop-blur-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent hover:border-gray-400 transition-all"
              value={pageSize}
              onChange={(e) => pagination.onPageSizeChange?.(parseInt(e.target.value, 10))}
            >
              {[10, 20, 50, 100].map((s) => (
                <option key={s} value={s}>{s} / page</option>
              ))}
            </select>

            {/* Divider */}
            <div className="w-px h-6 bg-gray-200" />

            {/* Pagination Info */}
            <span className="text-sm text-gray-600">
              Page <span className="font-semibold text-gray-900">{page}</span> of{" "}
              <span className="font-semibold text-gray-900">{pageCount}</span>
            </span>

            {/* Navigation Buttons */}
            <div className="flex items-center gap-1">
              <button
                className={clsx(
                  "p-2 rounded-lg transition-all duration-200",
                  page <= 1
                    ? "opacity-50 cursor-not-allowed"
                    : "hover:bg-gray-100 text-gray-600 hover:text-gray-900"
                )}
                disabled={page <= 1}
                onClick={() => pagination.onPageChange(page - 1)}
                title="Previous page"
              >
                <ChevronLeft size={18} />
              </button>
              <button
                className={clsx(
                  "p-2 rounded-lg transition-all duration-200",
                  page >= pageCount
                    ? "opacity-50 cursor-not-allowed"
                    : "hover:bg-gray-100 text-gray-600 hover:text-gray-900"
                )}
                disabled={page >= pageCount}
                onClick={() => pagination.onPageChange(page + 1)}
                title="Next page"
              >
                <ChevronRight size={18} />
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}