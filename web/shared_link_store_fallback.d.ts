export {};

declare global {
  interface Window {
    /** Available after shared_link_store_fallback.js loads. */
    KaizenSharedLinks?: Readonly<{
      /** Returns the device's official store URL, or null for desktop/unknown devices. */
      getStoreUrl(): string | null;
      /** Call from the dialog button. Returns false when no mobile store applies. */
      openStore(): boolean;
    }>;
  }
}
