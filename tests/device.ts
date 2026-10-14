import { devices } from "@playwright/test";

// iPad mini (6th gen) in portrait, run in Chromium (the projects are chromium-only).
export const DEVICE = {
  userAgent: devices["iPad Mini"].userAgent,
  viewport: { width: 744, height: 1133 },
  deviceScaleFactor: 2,
  isMobile: true,
  hasTouch: true,
};
