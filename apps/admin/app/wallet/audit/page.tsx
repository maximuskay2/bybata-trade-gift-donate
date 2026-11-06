"use client";
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Table } from '@/app/components/ui/table';

const fetcher = (url: string) => api.get(url).then((res) => res.data);

export default function WalletAuditPage() {
  const { data } = useSWR('/v1/admin/wallet/audit?page=1&size=50', fetcher);
  const items = data?.items || [];
  return (
    <div className="p-6 space-y-4">
      <h1 className="text-2xl font-semibold">Admin Wallet Audit</h1>
      <Table
        columns={[
          { header: 'Action', accessor: 'action' },
          { header: 'Admin', accessor: (row: any) => row.admin?.email || '-' },
          { header: 'Target User', accessor: (row: any) => row.targetUser?.email || '-' },
          { header: 'Details', accessor: (row: any) => JSON.stringify(row.details) },
          { header: 'Created At', accessor: 'createdAt' },
        ]}
        data={items}
      />
    </div>
  );
}
