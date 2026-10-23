const HOST_NAME = 'com.omarchy.ytdlp';

function sendUrl(url) {
  if (!url || !/^https?:/i.test(url)) return;

  // The native messaging host runs yt-dlp and owns all the desktop
  // notifications, so we just hand off the URL and ignore the reply.
  browser.runtime.sendNativeMessage(HOST_NAME, { url }).catch(() => {});
}

async function triggerDownload(tab) {
  if (!tab) return;

  // The activeTab permission exposes tab.url whenever the user invokes the
  // extension — both via the toolbar click and the keyboard shortcut.
  if (tab.url) {
    sendUrl(tab.url);
    return;
  }

  // Fallback: read the URL straight from the page.
  if (tab.id === undefined) return;
  try {
    const results = await browser.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => location.href,
    });
    sendUrl(results && results[0] && results[0].result);
  } catch {
    // Privileged pages (about:, addons.mozilla.org, …) refuse injection.
  }
}

// Keyboard shortcut (Alt+Shift+D).
browser.commands.onCommand.addListener(async (command) => {
  if (command !== 'download-video') return;

  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  triggerDownload(tabs[0]);
});

// Clicking the extension's toolbar icon.
browser.action.onClicked.addListener((tab) => {
  triggerDownload(tab);
});
