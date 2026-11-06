"use client";
import useSWR from "swr";
import { api } from '@/lib/api';
import { Card } from "@/app/components/ui/card";
import { Input } from '@/app/components/ui/input';
import { Button } from '@/app/components/ui/button';
import { useState, useEffect } from "react";
import { useToast } from '@/app/components/ui/use-toast';
import { Megaphone } from "lucide-react";

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function AdPricingSettingsPage() {
  const { data, mutate, isLoading } = useSWR("/v1/admin/settings/ad-pricing", fetcher);
  const { toast } = useToast();
  const [tradeBycPerDay, setTradeBycPerDay] = useState<number>(2.5);
  const [giftBycPerDay, setGiftBycPerDay] = useState<number>(2);
  const [donationBycPerDay, setDonationBycPerDay] = useState<number>(2);
  const [normalBycPerDay, setNormalBycPerDay] = useState<number>(3);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (data) {
      if (data.tradeBycPerDay != null) setTradeBycPerDay(data.tradeBycPerDay);
      if (data.giftBycPerDay != null) setGiftBycPerDay(data.giftBycPerDay);
      if (data.donationBycPerDay != null) setDonationBycPerDay(data.donationBycPerDay);
      if (data.normalBycPerDay != null) setNormalBycPerDay(data.normalBycPerDay);
    }
  }, [data?.tradeBycPerDay, data?.giftBycPerDay, data?.donationBycPerDay, data?.normalBycPerDay]);

  const save = async () => {
    try {
      const validate = (v: number, name: string) => {
        if (v < 0 || v > 1000) {
          toast({ title: "Invalid value", description: `${name} must be 0–1000 BYC per day`, variant: "destructive" });
          return false;
        }
        return true;
      };
      if (!validate(tradeBycPerDay, "Trade ads") || !validate(giftBycPerDay, "Gift ads") ||
          !validate(donationBycPerDay, "Donation ads") || !validate(normalBycPerDay, "Normal ads")) return;

      setIsSaving(true);
      await api.post("/v1/admin/settings/ad-pricing/upsert", {
        tradeBycPerDay: parseFloat(tradeBycPerDay.toFixed(2)),
        giftBycPerDay: parseFloat(giftBycPerDay.toFixed(2)),
        donationBycPerDay: parseFloat(donationBycPerDay.toFixed(2)),
        normalBycPerDay: parseFloat(normalBycPerDay.toFixed(2)),
      });
      toast({ title: "Saved", description: "Ad pricing settings updated" });
      mutate();
    } catch (e: any) {
      const msg = e?.response?.data?.message || e?.message || 'Unknown error';
      toast({ title: "Save failed", description: msg, variant: "destructive" });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Ad Pricing Settings</h1>
        <p className="text-muted-foreground mt-2">
          Set the BYC cost per day for ads across trade, gift, donation, and normal ad creation
        </p>
      </div>

      <Card className="p-6">
        <div className="space-y-6">
          <div className="flex items-center gap-2 mb-4">
            <Megaphone className="w-5 h-5 text-amber-600" />
            <h2 className="text-xl font-semibold">BYC per Day by Ad Type</h2>
          </div>
          <p className="text-sm text-muted-foreground">
            These values define how much BYC users pay per day when boosting trades, gifts, donation campaigns, or creating standalone ads.
            Configure Boost Configurations for min/max days and placement rules.
          </p>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <label htmlFor="trade" className="text-sm font-medium">Trade Ads (BYC/day)</label>
              <Input
                id="trade"
                type="number"
                min="0"
                max="1000"
                step="0.1"
                value={tradeBycPerDay}
                onChange={(e) => setTradeBycPerDay(parseFloat(e.target.value) || 0)}
                disabled={isLoading || isSaving}
                placeholder="2.5"
              />
            </div>
            <div className="space-y-2">
              <label htmlFor="gift" className="text-sm font-medium">Gift Ads (BYC/day)</label>
              <Input
                id="gift"
                type="number"
                min="0"
                max="1000"
                step="0.1"
                value={giftBycPerDay}
                onChange={(e) => setGiftBycPerDay(parseFloat(e.target.value) || 0)}
                disabled={isLoading || isSaving}
                placeholder="2"
              />
            </div>
            <div className="space-y-2">
              <label htmlFor="donation" className="text-sm font-medium">Donation Campaign Ads (BYC/day)</label>
              <Input
                id="donation"
                type="number"
                min="0"
                max="1000"
                step="0.1"
                value={donationBycPerDay}
                onChange={(e) => setDonationBycPerDay(parseFloat(e.target.value) || 0)}
                disabled={isLoading || isSaving}
                placeholder="2"
              />
            </div>
            <div className="space-y-2">
              <label htmlFor="normal" className="text-sm font-medium">Normal Ads Creation (BYC/day)</label>
              <Input
                id="normal"
                type="number"
                min="0"
                max="1000"
                step="0.1"
                value={normalBycPerDay}
                onChange={(e) => setNormalBycPerDay(parseFloat(e.target.value) || 0)}
                disabled={isLoading || isSaving}
                placeholder="3"
              />
            </div>
          </div>

          <div className="pt-4">
            <Button onClick={save} disabled={isLoading || isSaving} className="min-w-[120px]">
              {isSaving ? "Saving..." : "Save Settings"}
            </Button>
          </div>
        </div>
      </Card>

      <Card className="p-6 bg-muted/50">
        <div className="space-y-2">
          <h3 className="font-semibold">How it works</h3>
          <ul className="text-sm text-muted-foreground space-y-1 list-disc list-inside">
            <li>Users select how many days to run their ad when boosting in the Promotion Centre</li>
            <li>Cost = BYC per day × number of days (e.g. 2.5 BYC/day × 7 days = 17.5 BYC)</li>
            <li>Boost Configurations define min/max days and placement rules per boost type</li>
            <li>These pricing values are used when Boost Config uses DAILY pricing model</li>
          </ul>
        </div>
      </Card>
    </div>
  );
}
