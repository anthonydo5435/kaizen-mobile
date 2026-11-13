import type {} from "../../web/shared_link_store_fallback";

// The declaration must work in strict TypeScript without casting Window to any.
export const handleDialogButtonClick = (): void => {
  window.KaizenSharedLinks?.openStore();
};

export const readStoreUrl = (): string | null | undefined => window.KaizenSharedLinks?.getStoreUrl();
export const navigateOnClick = (): boolean | undefined => window.KaizenSharedLinks?.openStore();
