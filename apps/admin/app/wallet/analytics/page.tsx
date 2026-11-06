"use client";
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Card } from '@/app/components/ui/card';

const fetcher = (url: string) => api.get(url).then((res) => res.data);

export default function WalletAnalyticsPage() {
  const { data } = useSWR('/v1/admin/wallet/analytics', fetcher);
  const volume = data?.volumeByProvider || {};
  const failures = data?.failuresByProvider || {};
  const suspicious = data?.suspicious || [];
  return (
    <div className="p-6 space-y-4">
      <h1 className="text-2xl font-semibold">Wallet Analytics</h1>
      <Card className="p-4">
        <h2 className="font-medium mb-2">Volumes</h2>
        <pre className="text-sm">{JSON.stringify(volume, null, 2)}</pre>
      </Card>
      <Card className="p-4">
        <h2 className="font-medium mb-2">Failures</h2>
        <pre className="text-sm">{JSON.stringify(failures, null, 2)}</pre>
      </Card>
      <Card className="p-4">
        <h2 className="font-medium mb-2">Suspicious</h2>
        <pre className="text-sm">{JSON.stringify(suspicious, null, 2)}</pre>
      </Card>
    </div>
  );
}
