"use client";
import useSWR from "swr";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Card } from "@/app/components/ui/card";
import { Input } from "@/app/components/ui/input";
import { Button } from "@/app/components/ui/button";
import {
  Select,
  SelectTrigger,
  SelectContent,
  SelectItem,
  SelectValue,
} from "@/app/components/ui/select";
import { useToast } from "@/app/components/ui/use-toast";

const fetcher = (url: string) => api.get(url).then((r) => r.data);

type ProviderId = "ebulksms" | "twilio";

type ChannelsState = {
  smsEnabled: boolean;
  whatsappEnabled: boolean;
  smsProvider: ProviderId | null;
  whatsappProvider: ProviderId | null;
};

export default function MessagingSettingsPage() {
  const { data, mutate } = useSWR("/v1/admin/settings/messaging", fetcher);
  const { toast } = useToast();

  const [channels, setChannels] = useState<ChannelsState>({
    smsEnabled: false,
    whatsappEnabled: false,
    smsProvider: null,
    whatsappProvider: null,
  });
  const [ebulksms, setEbulksms] = useState<any>({
    enabled: false,
    username: "",
    apiKey: "",
    smsSender: "Bybata",
    whatsappSubject: "Bybata OTP",
    dndSender: false,
  });
  const [twilio, setTwilio] = useState<any>({
    enabled: false,
    accountSid: "",
    authToken: "",
    fromNumber: "",
    whatsappFrom: "",
  });
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!data) return;
    if (data.channels) {
      setChannels({
        smsEnabled: Boolean(data.channels.smsEnabled),
        whatsappEnabled: Boolean(data.channels.whatsappEnabled),
        smsProvider: data.channels.smsProvider || null,
        whatsappProvider: data.channels.whatsappProvider || null,
      });
    }
    if (data.ebulksms) {
      setEbulksms((prev: any) => ({
        ...prev,
        ...data.ebulksms,
        apiKey: "",
      }));
    }
    if (data.twilio) {
      setTwilio((prev: any) => ({
        ...prev,
        ...data.twilio,
        authToken: "",
      }));
    }
  }, [data]);

  const save = async () => {
    setSaving(true);
    try {
      await api.post("/v1/admin/settings/messaging/upsert", {
        channels: {
          smsEnabled: channels.smsEnabled,
          whatsappEnabled: channels.whatsappEnabled,
          smsProvider: channels.smsEnabled ? channels.smsProvider : null,
          whatsappProvider: channels.whatsappEnabled
            ? channels.whatsappProvider
            : null,
        },
        ebulksms: {
          enabled: Boolean(ebulksms.enabled),
          username: ebulksms.username,
          smsSender: ebulksms.smsSender,
          whatsappSubject: ebulksms.whatsappSubject,
          dndSender: Boolean(ebulksms.dndSender),
          ...(ebulksms.apiKey?.trim() ? { apiKey: ebulksms.apiKey.trim() } : {}),
        },
        twilio: {
          enabled: Boolean(twilio.enabled),
          accountSid: twilio.accountSid,
          fromNumber: twilio.fromNumber,
          whatsappFrom: twilio.whatsappFrom,
          ...(twilio.authToken?.trim()
            ? { authToken: twilio.authToken.trim() }
            : {}),
        },
      });
      toast({
        title: "Saved",
        description: "SMS / WhatsApp messaging settings updated",
      });
      mutate();
      setEbulksms((p: any) => ({ ...p, apiKey: "" }));
      setTwilio((p: any) => ({ ...p, authToken: "" }));
    } catch (e: any) {
      toast({
        title: "Save failed",
        description: e?.response?.data?.message || e.message,
        variant: "destructive",
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">SMS & WhatsApp OTP</h1>
        <p className="text-sm text-gray-600 mt-1">
          Configure EbulkSMS and Twilio for phone verification. Enable SMS,
          WhatsApp, or both, and pick which provider handles each channel.
        </p>
      </div>

      <Card className="p-4">
        <div className="flex flex-col gap-1 text-sm">
          <div>
            <span className="font-medium">Secrets storage:</span>{" "}
            <span
              className={
                data?.encryptionStatus === "encrypted"
                  ? "text-green-700"
                  : "text-amber-700"
              }
            >
              {data?.encryptionStatus === "encrypted"
                ? "Encrypted"
                : "Plaintext"}
            </span>
          </div>
          <p className="text-xs text-gray-500 mt-1">
            Docs:{" "}
            <a
              className="underline"
              href="https://www.ebulksms.com/pages/php-sample-code"
              target="_blank"
              rel="noreferrer"
            >
              EbulkSMS sample
            </a>
            {" · "}
            <a
              className="underline"
              href="https://www.ebulksms.com/pages/json-whatsapp-api"
              target="_blank"
              rel="noreferrer"
            >
              EbulkSMS WhatsApp
            </a>
            {" · "}
            <a
              className="underline"
              href="https://www.twilio.com/docs/sms"
              target="_blank"
              rel="noreferrer"
            >
              Twilio SMS
            </a>
          </p>
        </div>
      </Card>

      <Card className="p-4 space-y-4">
        <h2 className="font-medium">Delivery channels</h2>
        <p className="text-xs text-gray-600">
          You can enable SMS only, WhatsApp only, or both. Each channel uses one
          provider (EbulkSMS or Twilio).
        </p>

        <label className="flex items-center gap-3 text-sm">
          <input
            type="checkbox"
            checked={channels.smsEnabled}
            onChange={(e) =>
              setChannels({ ...channels, smsEnabled: e.target.checked })
            }
          />
          Send OTP via SMS
        </label>
        {channels.smsEnabled && (
          <div className="pl-6 max-w-sm">
            <label className="block text-sm mb-1">SMS provider</label>
            <Select
              value={channels.smsProvider || ""}
              onValueChange={(v: ProviderId) =>
                setChannels({ ...channels, smsProvider: v })
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Select provider" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ebulksms">EbulkSMS</SelectItem>
                <SelectItem value="twilio">Twilio</SelectItem>
              </SelectContent>
            </Select>
          </div>
        )}

        <label className="flex items-center gap-3 text-sm">
          <input
            type="checkbox"
            checked={channels.whatsappEnabled}
            onChange={(e) =>
              setChannels({ ...channels, whatsappEnabled: e.target.checked })
            }
          />
          Send OTP via WhatsApp
        </label>
        {channels.whatsappEnabled && (
          <div className="pl-6 max-w-sm">
            <label className="block text-sm mb-1">WhatsApp provider</label>
            <Select
              value={channels.whatsappProvider || ""}
              onValueChange={(v: ProviderId) =>
                setChannels({ ...channels, whatsappProvider: v })
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Select provider" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ebulksms">EbulkSMS WhatsApp</SelectItem>
                <SelectItem value="twilio">Twilio WhatsApp</SelectItem>
              </SelectContent>
            </Select>
          </div>
        )}
      </Card>

      <Card className="p-4 space-y-4">
        <div className="flex items-center justify-between gap-3">
          <h2 className="font-medium">EbulkSMS</h2>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={Boolean(ebulksms.enabled)}
              onChange={(e) =>
                setEbulksms({ ...ebulksms, enabled: e.target.checked })
              }
            />
            Provider enabled
          </label>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm mb-1">Username (email)</label>
            <Input
              value={ebulksms.username || ""}
              onChange={(e) =>
                setEbulksms({ ...ebulksms, username: e.target.value })
              }
              placeholder="you@example.com"
            />
          </div>
          <div>
            <label className="block text-sm mb-1">API Key</label>
            <Input
              type="password"
              placeholder={ebulksms?.apiKeyMasked || "••••••••"}
              value={ebulksms.apiKey || ""}
              onChange={(e) =>
                setEbulksms({ ...ebulksms, apiKey: e.target.value })
              }
            />
            {ebulksms?.hasApiKey && (
              <p className="text-xs text-gray-500 mt-1">
                Key on file ({ebulksms.apiKeyMasked}). Leave blank to keep.
              </p>
            )}
          </div>
          <div>
            <label className="block text-sm mb-1">SMS sender name</label>
            <Input
              value={ebulksms.smsSender || ""}
              onChange={(e) =>
                setEbulksms({ ...ebulksms, smsSender: e.target.value })
              }
              placeholder="Bybata"
              maxLength={11}
            />
          </div>
          <div>
            <label className="block text-sm mb-1">WhatsApp subject</label>
            <Input
              value={ebulksms.whatsappSubject || ""}
              onChange={(e) =>
                setEbulksms({ ...ebulksms, whatsappSubject: e.target.value })
              }
              placeholder="Bybata OTP"
            />
          </div>
          <label className="flex items-center gap-3 text-sm">
            <input
              type="checkbox"
              checked={Boolean(ebulksms.dndSender)}
              onChange={(e) =>
                setEbulksms({ ...ebulksms, dndSender: e.target.checked })
              }
            />
            Enable DND sender (MTN Nigeria, higher unit cost)
          </label>
        </div>
      </Card>

      <Card className="p-4 space-y-4">
        <div className="flex items-center justify-between gap-3">
          <h2 className="font-medium">Twilio</h2>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={Boolean(twilio.enabled)}
              onChange={(e) =>
                setTwilio({ ...twilio, enabled: e.target.checked })
              }
            />
            Provider enabled
          </label>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm mb-1">Account SID</label>
            <Input
              value={twilio.accountSid || ""}
              onChange={(e) =>
                setTwilio({ ...twilio, accountSid: e.target.value })
              }
              placeholder="ACxxxxxxxx"
            />
          </div>
          <div>
            <label className="block text-sm mb-1">Auth Token</label>
            <Input
              type="password"
              placeholder={twilio?.authTokenMasked || "••••••••"}
              value={twilio.authToken || ""}
              onChange={(e) =>
                setTwilio({ ...twilio, authToken: e.target.value })
              }
            />
            {twilio?.hasAuthToken && (
              <p className="text-xs text-gray-500 mt-1">
                Token on file ({twilio.authTokenMasked}). Leave blank to keep.
              </p>
            )}
          </div>
          <div>
            <label className="block text-sm mb-1">SMS From number</label>
            <Input
              value={twilio.fromNumber || ""}
              onChange={(e) =>
                setTwilio({ ...twilio, fromNumber: e.target.value })
              }
              placeholder="+15551234567"
            />
          </div>
          <div>
            <label className="block text-sm mb-1">WhatsApp From</label>
            <Input
              value={twilio.whatsappFrom || ""}
              onChange={(e) =>
                setTwilio({ ...twilio, whatsappFrom: e.target.value })
              }
              placeholder="whatsapp:+15551234567"
            />
          </div>
        </div>
      </Card>

      <div className="flex justify-end">
        <Button onClick={save} disabled={saving}>
          {saving ? "Saving…" : "Save settings"}
        </Button>
      </div>
    </div>
  );
}
