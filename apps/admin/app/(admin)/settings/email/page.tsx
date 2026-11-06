"use client";
import useSWR from "swr";
import { useState, useEffect } from "react";
import { api } from "@/lib/api";
import { Card } from "@/app/components/ui/card";
import { Input } from "@/app/components/ui/input";
import { Button } from "@/app/components/ui/button";
import { Select, SelectTrigger, SelectContent, SelectItem, SelectValue } from "@/app/components/ui/select";
import { useToast } from "@/app/components/ui/use-toast";

const fetcher = (url: string) => api.get(url).then((r) => r.data);

type Provider = "resend" | "smtp" | "sendgrid";

export default function EmailSettingsPage() {
  const { data, mutate } = useSWR("/v1/admin/settings/email", fetcher);
  const { toast } = useToast();
  const [activeProvider, setActiveProvider] = useState<Provider>("resend");
  const [resend, setResend] = useState<any>({});
  const [smtp, setSmtp] = useState<any>({});
  const [sendgrid, setSendgrid] = useState<any>({});

  const parseJson = (value: string, fallback: any) => {
    try {
      return JSON.parse(value || "{}");
    } catch {
      return fallback;
    }
  };

  useEffect(() => {
    if (data?.activeProvider) setActiveProvider(data.activeProvider);
    if (data?.resend) setResend(data.resend);
    if (data?.smtp) setSmtp(data.smtp);
    if (data?.sendgrid) setSendgrid(data.sendgrid);
  }, [data]);

  const save = async () => {
    try {
      await api.post("/v1/admin/settings/email/upsert", {
        provider: activeProvider,
        active: true,
        resend,
        smtp,
        sendgrid,
      });
      toast({ title: "Saved", description: "Email settings updated" });
      mutate();
    } catch (e: any) {
      toast({
        title: "Save failed",
        description: e?.response?.data?.message || e.message,
        variant: "destructive",
      });
    }
  };

  const setActive = async (provider: Provider) => {
    setActiveProvider(provider);
    try {
      await api.post("/v1/admin/settings/email/set-active", { provider });
      toast({ title: "Active provider updated", description: provider.toUpperCase() });
      mutate();
    } catch (e: any) {
      toast({
        title: "Update failed",
        description: e?.response?.data?.message || e.message,
        variant: "destructive",
      });
    }
  };

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Email Provider Settings</h1>

      <Card className="p-4">
        <div className="flex flex-col gap-1 text-sm">
          <div>
            <span className="font-medium">Active provider:</span>{" "}
            <span className="uppercase">{data?.activeProvider || activeProvider}</span>
          </div>
          <div>
            <span className="font-medium">Secrets storage:</span>{" "}
            <span className={data?.encryptionStatus === "encrypted" ? "text-green-700" : "text-amber-700"}>
              {data?.encryptionStatus === "encrypted" ? "Encrypted" : "Plaintext"}
            </span>
          </div>
        </div>
      </Card>

      <Card className="p-4 space-y-4">
        <div>
          <label className="block text-sm mb-1">Active Provider</label>
          <Select value={activeProvider} onValueChange={(v: Provider) => setActive(v)}>
            <SelectTrigger>
              <SelectValue placeholder="Select provider" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="resend">Resend</SelectItem>
              <SelectItem value="smtp">SMTP (Hostinger)</SelectItem>
              <SelectItem value="sendgrid">SendGrid</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </Card>

      <Card className="p-4 space-y-4">
        <h2 className="font-medium">Resend</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm mb-1">API Key</label>
            <Input
              type="password"
              placeholder={resend?.apiKeyMasked || "re_*****"}
              onChange={(e) => setResend({ ...resend, apiKey: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-sm mb-1">From</label>
            <Input
              value={resend?.from || ""}
              onChange={(e) => setResend({ ...resend, from: e.target.value })}
              placeholder="no-reply@yourdomain.com"
            />
          </div>
          <label className="flex items-center gap-3 text-sm">
            <input
              type="checkbox"
              checked={Boolean(resend?.useTemplateApi)}
              onChange={(e) => setResend({ ...resend, useTemplateApi: e.target.checked })}
            />
            Use Resend Template API
          </label>
          <div>
            <label className="block text-sm mb-1">Template Map (JSON)</label>
            <Input
              value={JSON.stringify(resend?.templateMap || {})}
              onChange={(e) =>
                setResend({ ...resend, templateMap: parseJson(e.target.value, resend?.templateMap || {}) })
              }
            />
          </div>
        </div>
      </Card>

      <Card className="p-4 space-y-4">
        <h2 className="font-medium">SMTP (Hostinger)</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm mb-1">Host</label>
            <Input
              value={smtp?.host || ""}
              onChange={(e) => setSmtp({ ...smtp, host: e.target.value })}
              placeholder="smtp.hostinger.com"
            />
          </div>
          <div>
            <label className="block text-sm mb-1">Port</label>
            <Input
              value={smtp?.port || ""}
              onChange={(e) => setSmtp({ ...smtp, port: Number(e.target.value) })}
              placeholder="465"
            />
          </div>
          <div>
            <label className="block text-sm mb-1">User</label>
            <Input
              value={smtp?.user || ""}
              onChange={(e) => setSmtp({ ...smtp, user: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-sm mb-1">Password</label>
            <Input
              type="password"
              placeholder={smtp?.passMasked || "********"}
              onChange={(e) => setSmtp({ ...smtp, pass: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-sm mb-1">From</label>
            <Input
              value={smtp?.from || ""}
              onChange={(e) => setSmtp({ ...smtp, from: e.target.value })}
            />
          </div>
          <label className="flex items-center gap-3 text-sm">
            <input
              type="checkbox"
              checked={Boolean(smtp?.secure)}
              onChange={(e) => setSmtp({ ...smtp, secure: e.target.checked })}
            />
            Use TLS/SSL
          </label>
        </div>
      </Card>

      <Card className="p-4 space-y-4">
        <h2 className="font-medium">SendGrid</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm mb-1">API Key</label>
            <Input
              type="password"
              placeholder={sendgrid?.apiKeyMasked || "SG.*****"}
              onChange={(e) => setSendgrid({ ...sendgrid, apiKey: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-sm mb-1">From</label>
            <Input
              value={sendgrid?.from || ""}
              onChange={(e) => setSendgrid({ ...sendgrid, from: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-sm mb-1">Template Map (JSON)</label>
            <Input
              value={JSON.stringify(sendgrid?.templateMap || {})}
              onChange={(e) =>
                setSendgrid({ ...sendgrid, templateMap: parseJson(e.target.value, sendgrid?.templateMap || {}) })
              }
            />
          </div>
        </div>
      </Card>

      <div className="flex gap-2">
        <Button onClick={save}>Save Settings</Button>
      </div>
    </div>
  );
}
