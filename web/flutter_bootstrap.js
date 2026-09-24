{{flutter_js}}
{{flutter_build_config}}

(async function bootstrapApp() {
  // Replaced with the current main.dart.js hash by the release build step.
  // A changed release clears obsolete Flutter caches once and reloads once.
  const cleanupVersion = '__WEB_CACHE_VERSION__';
  const cleanupKey = 'keshkart_web_cache_cleanup_version';
  const reloadKey = 'keshkart_web_cache_cleanup_reloaded';

  async function cleanupStaleAppCaches() {
    let storage;
    let session;
    try {
      storage = window.localStorage;
      session = window.sessionStorage;
    } catch (_) {
      storage = null;
      session = null;
    }

    const alreadyCleaned = storage && storage.getItem(cleanupKey) === cleanupVersion;
    if (alreadyCleaned) return true;

    let changed = false;
    if ('serviceWorker' in navigator) {
      try {
        const registrations = await navigator.serviceWorker.getRegistrations();
        await Promise.all(registrations.map(function(registration) {
          changed = true;
          return registration.unregister();
        }));
      } catch (error) {
        console.warn('KeshKart update cleanup skipped a service worker', error);
      }
    }

    if ('caches' in window) {
      try {
        const names = await caches.keys();
        if (names.length > 0) changed = true;
        await Promise.all(names.map(function(name) { return caches.delete(name); }));
      } catch (error) {
        console.warn('KeshKart update cleanup skipped Cache Storage', error);
      }
    }

    if (storage) storage.setItem(cleanupKey, cleanupVersion);

    if (changed && session && session.getItem(reloadKey) !== cleanupVersion) {
      session.setItem(reloadKey, cleanupVersion);
      window.location.reload();
      return false;
    }
    return true;
  }

  if (!await cleanupStaleAppCaches()) return;

  _flutter.loader.load({
    onEntrypointLoaded: async function(engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine({
        useColorEmoji: false,
      });
      await appRunner.runApp();
    }
  });
})();