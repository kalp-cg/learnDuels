const { test, expect } = require('@playwright/test');

test('flutter web app bootstraps', async ({ page }) => {
  await page.goto('/');

  // Flutter web injects this host element once the app runtime is mounted.
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'), {
    timeout: 30000
  });
  await expect(page.locator('body')).toBeAttached();
});
