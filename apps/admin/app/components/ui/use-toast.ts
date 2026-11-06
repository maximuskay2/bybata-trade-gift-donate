// Simple toast function that matches shadcn/ui API but works with our existing toast system
export const toast = (options: { title: string; description?: string; variant?: "default" | "destructive" }) => {
  // This is a simple client-side implementation that works without the provider
  console.log('Toast:', options);
};

export const useToast = () => ({
  toast
});
