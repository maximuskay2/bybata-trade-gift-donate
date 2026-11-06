"use client";
import { useEffect, useState } from 'react';
import useSWR from 'swr';
import { api } from '@/lib/api';
import { Card } from '@/app/components/ui/card';
import { Input } from '@/app/components/ui/input';
import { Button } from '@/app/components/ui/button';
import { useToast } from '@/app/components/ui/use-toast';

export default function WalletCreditPage() {
  const [query, setQuery] = useState("");
  const [userId, setUserId] = useState("");
  const [amountByc, setAmountByc] = useState(0);
  const [memo, setMemo] = useState("");
  const { toast } = useToast();

  const fetcher = (url: string) => api.get(url).then(res => res.data);
  const { data, mutate } = useSWR(query ? `/v1/admin/users?query=${encodeURIComponent(query)}&size=10` : null, fetcher);
  const users = (data?.items ?? []) as any[];

  useEffect(() => {
    if (users.length && !userId) {
      setUserId(users[0].id);
    }
  }, [users]);

  const submit = async () => {
    try {
      const res = await api.post('/v1/admin/wallet/credit', { userId, amountByc, memo });
      toast({ title: 'Wallet credited', description: `TX: ${res.data.transactionId}` });
    } catch (e: any) {
      toast({ title: 'Credit failed', description: e?.response?.data?.message || e.message, variant: 'destructive' });
    }
  };

  return (
    <div className="p-6 space-y-4">
      <h1 className="text-2xl font-semibold">Admin Wallet Credit</h1>
      <Card className="p-4 space-y-3">
        <div>
          <label className="block text-sm mb-1">Search users</label>
          <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="email or display name" />
        </div>
        {users.length > 0 && (
          <div className="space-y-2">
            {users.map((u) => (
              <div key={u.id} className={`flex items-center justify-between p-2 border rounded ${userId === u.id ? 'border-blue-500' : 'border-gray-200'}`}>
                <div>
                  <div className="text-sm font-medium">{u.profile?.displayName || '-'}</div>
                  <div className="text-xs text-gray-500">{u.email}</div>
                </div>
                <Button variant={userId === u.id ? 'default' : 'secondary'} onClick={() => setUserId(u.id)}>
                  {userId === u.id ? 'Selected' : 'Select'}
                </Button>
              </div>
            ))}
          </div>
        )}
        <div>
          <label className="block text-sm mb-1">User ID</label>
          <Input value={userId} onChange={(e) => setUserId(e.target.value)} placeholder="user id" />
        </div>
        <div>
          <label className="block text-sm mb-1">Amount (BYC)</label>
          <Input type="number" value={amountByc} onChange={(e) => setAmountByc(parseFloat(e.target.value))} />
        </div>
        <div>
          <label className="block text-sm mb-1">Memo</label>
          <Input value={memo} onChange={(e) => setMemo(e.target.value)} placeholder="optional memo" />
        </div>
        <Button onClick={submit}>Credit Wallet</Button>
      </Card>
    </div>
  );
}
