"use client";
import useSWR from "swr";
import { api } from '@/lib/api';
import { Card } from "@/app/components/ui/card";
import { Input } from '@/app/components/ui/input';
import { Button } from '@/app/components/ui/button';
import { Select, SelectTrigger, SelectContent, SelectItem, SelectValue } from '@/app/components/ui/select';
import { useState } from "react";
import { useToast } from '@/app/components/ui/use-toast';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

type FormState = {
  gateway: "paystack" | "stripe" | "paypal" | "flutterwave";
  mode: "test" | "live";
  publicKey: string;
  secretKey: string;
  webhookUrl?: string;
  webhookSecret?: string;
  currencies?: string;
  active?: boolean;
};

export default function GatewaySettingsPage() {
  const { data, mutate } = useSWR("/v1/admin/settings/gateways", fetcher);
  const { toast } = useToast();
  const [form, setForm] = useState<FormState>({
    gateway: "paystack",
    mode: "test",
    publicKey: "",
    secretKey: "",
    webhookUrl: "",
    webhookSecret: "",
    currencies: "USD,NGN",
    active: true,
  });

  const requiredFields = () => {
    switch (form.gateway) {
      case 'stripe': return ['publicKey', 'secretKey'];
      case 'paystack': return ['publicKey', 'secretKey'];
      case 'paypal': return ['publicKey', 'secretKey'];
      case 'flutterwave': return ['publicKey', 'secretKey'];
      default: return [];
    }
  };

  const verify = async () => {
    try {
      const res = await api.post('/v1/admin/settings/gateways/verify', form);
      toast({ title: 'Verification', description: res.data.ok ? 'Credentials verified' : `Failed (${res.data.status || res.data.error})`, variant: res.data.ok ? 'default' : 'destructive' });
    } catch (e: any) {
      toast({ title: 'Verification failed', description: e?.response?.data?.message || e.message, variant: 'destructive' });
    }
  };

  const save = async () => {
    try {
      // validation
      if (!form.gateway || !form.mode) {
        toast({ title: "Missing fields", description: "Gateway and Mode are required", variant: "destructive" });
        return;
      }
      if (!form.publicKey || !form.publicKey.trim()) {
        toast({ title: "Missing keys", description: "Public key is required", variant: "destructive" });
        return;
      }
      if (!form.secretKey || !form.secretKey.trim()) {
        toast({ title: "Missing keys", description: "Secret key is required", variant: "destructive" });
        return;
      }
      if (form.webhookUrl && form.webhookUrl.trim()) {
        try { new URL(form.webhookUrl); } catch { 
          toast({ title: "Invalid webhook URL", description: "Please enter a valid URL", variant: "destructive" }); 
          return; 
        }
      }
      
      // Prepare payload - only send non-empty optional fields
      const payload: any = {
        gateway: form.gateway,
        mode: form.mode,
        publicKey: form.publicKey.trim(),
        secretKey: form.secretKey.trim(),
        active: form.active ?? true,
      };
      
      if (form.webhookUrl?.trim()) payload.webhookUrl = form.webhookUrl.trim();
      if (form.webhookSecret?.trim()) payload.webhookSecret = form.webhookSecret.trim();
      if (form.currencies?.trim()) payload.currencies = form.currencies.trim();
      
      await api.post("/v1/admin/settings/gateways/upsert", payload);
      toast({ title: "Saved", description: "Gateway configuration saved" });
      mutate();
    } catch (e: any) {
      const errorMessage = e?.response?.data?.message || e?.message || 'Unknown error occurred';
      toast({ title: "Save failed", description: errorMessage, variant: "destructive" });
      console.error('Gateway save error:', e?.response?.data || e);
    }
  };

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Payment Gateway Settings</h1>
      <Card className="p-4 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm mb-1">Gateway</label>
            <Select value={form.gateway} onValueChange={(v: any) => setForm({ ...form, gateway: v })}>
              <SelectTrigger>
                <SelectValue placeholder="Select gateway" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="paystack">Paystack</SelectItem>
                <SelectItem value="stripe">Stripe</SelectItem>
                <SelectItem value="paypal">PayPal</SelectItem>
                <SelectItem value="flutterwave">Flutterwave</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <label className="block text-sm mb-1">Mode</label>
            <Select value={form.mode} onValueChange={(v: any) => setForm({ ...form, mode: v })}>
              <SelectTrigger>
                <SelectValue placeholder="Select mode" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="test">Test</SelectItem>
                <SelectItem value="live">Live</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <label className="block text-sm mb-1">{form.gateway === 'stripe' ? 'Publishable Key' : form.gateway === 'paypal' ? 'Client ID' : 'Public Key'}</label>
            <Input value={form.publicKey} onChange={(e) => setForm({ ...form, publicKey: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm mb-1">{form.gateway === 'stripe' ? 'Secret Key' : form.gateway === 'paypal' ? 'Client Secret' : 'Secret Key'}</label>
            <Input type="password" value={form.secretKey} onChange={(e) => setForm({ ...form, secretKey: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm mb-1">Webhook URL</label>
            <Input value={form.webhookUrl} onChange={(e) => setForm({ ...form, webhookUrl: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm mb-1">Webhook Secret</label>
            <Input value={form.webhookSecret} onChange={(e) => setForm({ ...form, webhookSecret: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm mb-1">Supported Currencies (comma-separated)</label>
            <Input value={form.currencies} onChange={(e) => setForm({ ...form, currencies: e.target.value })} />
          </div>
        </div>
        <div className="flex gap-2">
          <Button onClick={save}>Save Configuration</Button>
          <Button variant="secondary" onClick={verify}>Verify Credentials</Button>
        </div>
      </Card>

      <Card className="p-4 space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="font-medium">Existing Configurations</h2>
          <span className={`text-xs px-2 py-1 rounded ${form.mode === 'test' ? 'bg-yellow-100 text-yellow-700' : 'bg-green-100 text-green-700'}`}>Mode: {form.mode.toUpperCase()}</span>
        </div>
        <div className="overflow-auto rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-200 bg-gradient-to-r from-gray-50 to-gray-50 text-left text-gray-700 font-semibold">
                <th className="px-6 py-4">Gateway</th>
                <th className="px-6 py-4">Mode</th>
                <th className="px-6 py-4">Public Key</th>
                <th className="px-6 py-4">Secret Key</th>
                <th className="px-6 py-4">Webhook</th>
                <th className="px-6 py-4">Active</th>
                <th className="px-6 py-4">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {(data?.items ?? []).map((it: any, idx: number) => {
                const maskedSecret = it.secretKey ? `****${String(it.secretKey).slice(-4)}` : '';
                return (
                  <tr key={idx} className="hover:bg-gray-50 transition-all duration-200">
                    <td className="px-6 py-4 capitalize text-gray-900">{it.gateway}</td>
                    <td className="px-6 py-4 uppercase text-gray-700">{it.mode}</td>
                    <td className="px-6 py-4 break-all text-gray-700">{it.publicKey}</td>
                    <td className="px-6 py-4 text-gray-700">{maskedSecret}</td>
                    <td className="px-6 py-4 break-all text-gray-700">{it.webhookUrl || '-'}</td>
                    <td className="px-6 py-4 text-gray-700">{it.active ? 'Yes' : 'No'}</td>
                    <td className="px-6 py-4 flex gap-2 flex-wrap">
                      {it.active ? (
                        <Button variant="outline" size="sm" onClick={async () => {
                          try {
                            await api.post('/v1/admin/settings/gateways/deactivate', { gateway: it.gateway, mode: it.mode });
                            toast({ title: 'Deactivated', description: `${it.gateway} is now hidden from users` });
                            mutate();
                          } catch (e: any) {
                            toast({ title: 'Deactivate failed', description: e?.response?.data?.message || e.message, variant: 'destructive' });
                          }
                        }}>Deactivate</Button>
                      ) : (
                        <Button variant="outline" size="sm" onClick={async () => {
                          try {
                            await api.post('/v1/admin/settings/gateways/activate', { gateway: it.gateway, mode: it.mode });
                            toast({ title: 'Activated', description: `${it.gateway} is now available to users` });
                            mutate();
                          } catch (e: any) {
                            toast({ title: 'Activate failed', description: e?.response?.data?.message || e.message, variant: 'destructive' });
                          }
                        }}>Activate</Button>
                      )}
                      <Button variant="secondary" size="sm" onClick={async () => {
                        try { const res = await api.post('/v1/admin/settings/gateways/ping-webhook', { gateway: it.gateway, mode: it.mode }); toast({ title: 'Ping', description: res.data.ok ? 'Webhook reachable' : `Failed (${res.data.status || res.data.error})` }); } catch (e: any) { toast({ title: 'Ping failed', description: e?.response?.data?.message || e.message, variant: 'destructive' }); }
                      }}>Ping Webhook</Button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <p className="text-xs text-gray-500">
          Note: Never share secret keys publicly. Use Test mode for sandbox environments.
          All active gateways are shown to users based on their selected currency (NGN/GHS/KES/ZAR → Paystack & Flutterwave; USD → Stripe & PayPal).
        </p>
      </Card>
    </div>
  );
}
