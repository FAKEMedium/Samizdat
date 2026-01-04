/**
 * Samizdat Service Worker
 *
 * Provides pattern-based caching for dynamic routes.
 * Routes are configured via /sw-routes.json endpoint.
 *
 * Features:
 * - Maps dynamic URLs (e.g., /rs/web/menus/123) to static cache files
 * - Cookie-based language support
 * - Automatic cache versioning
 * - Offline support for cached pages
 */

const CACHE_NAME = 'samizdat-v<%= $version %>';
const CONFIG_URL = '/sw-routes.json';

// Route patterns loaded from config
let routePatterns = [];
let defaultLanguage = 'en';

/**
 * Install event - cache config and pre-cache any specified assets
 */
self.addEventListener('install', (event) => {
  console.log('[SW] Installing...');
  event.waitUntil(
    loadConfig()
      .then(() => self.skipWaiting())
      .catch(err => console.error('[SW] Install failed:', err))
  );
});

/**
 * Activate event - clean old caches and claim clients
 */
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating...');
  event.waitUntil(
    Promise.all([
      // Clean old cache versions
      caches.keys().then(keys => Promise.all(
        keys.filter(key => key !== CACHE_NAME)
            .map(key => caches.delete(key))
      )),
      // Take control of all clients immediately
      self.clients.claim()
    ])
  );
});

/**
 * Fetch event - intercept requests and serve from cache when applicable
 */
self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Only handle GET requests
  if (request.method !== 'GET') return;

  // Only handle navigation and same-origin requests
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Check if this URL matches any of our route patterns
  const match = findMatchingRoute(url.pathname);

  if (match) {
    event.respondWith(handleCachedRoute(request, match));
  }
});

/**
 * Message event - handle commands from main thread
 */
self.addEventListener('message', (event) => {
  const { type, data } = event.data || {};

  switch (type) {
    case 'REFRESH_CONFIG':
      loadConfig().then(() => {
        event.ports[0]?.postMessage({ success: true });
      });
      break;

    case 'CLEAR_CACHE':
      caches.delete(CACHE_NAME).then(() => {
        event.ports[0]?.postMessage({ success: true });
      });
      break;

    case 'GET_CONFIG':
      event.ports[0]?.postMessage({ routePatterns, defaultLanguage });
      break;
  }
});

/**
 * Load route configuration from server
 */
async function loadConfig() {
  try {
    const response = await fetch(CONFIG_URL, { cache: 'no-store' });
    if (!response.ok) throw new Error(`Config fetch failed: ${response.status}`);

    const config = await response.json();
    routePatterns = (config.routes || []).map(route => ({
      ...route,
      regex: new RegExp(route.pattern)
    }));
    defaultLanguage = config.defaultLanguage || 'en';

    console.log(`[SW] Loaded ${routePatterns.length} route patterns`);

    // Pre-cache specified files if any
    if (config.precache && config.precache.length > 0) {
      const cache = await caches.open(CACHE_NAME);
      await cache.addAll(config.precache);
    }

    return true;
  } catch (err) {
    console.error('[SW] Failed to load config:', err);
    return false;
  }
}

/**
 * Find a matching route pattern for the given path
 */
function findMatchingRoute(pathname) {
  for (const route of routePatterns) {
    const match = pathname.match(route.regex);
    if (match) {
      return { route, match };
    }
  }
  return null;
}

/**
 * Extract language from cookies
 */
function getLanguageFromCookies(cookieHeader) {
  if (!cookieHeader) return defaultLanguage;

  // Check editlanguage cookie first (for editing), then regular language cookie
  const editMatch = cookieHeader.match(/editlanguage=([a-z]{2})/);
  if (editMatch) return editMatch[1];

  const langMatch = cookieHeader.match(/\blanguage=([a-z]{2})/);
  if (langMatch) return langMatch[1];

  return defaultLanguage;
}

/**
 * Build the cache file path from route config and matched groups
 */
function buildCachePath(route, match, lang) {
  let cachePath = route.cachePath;

  // Replace $1, $2, etc. with matched groups
  for (let i = 1; i < match.length; i++) {
    cachePath = cachePath.replace(`$${i}`, match[i]);
  }

  // Replace {lang} placeholder with actual language
  cachePath = cachePath.replace('{lang}', lang);

  return cachePath;
}

/**
 * Handle a request that matches a cached route
 */
async function handleCachedRoute(request, { route, match }) {
  const cookies = request.headers.get('cookie') || '';
  const lang = getLanguageFromCookies(cookies);
  const cachePath = buildCachePath(route, match, lang);

  const cache = await caches.open(CACHE_NAME);

  // Try cache first
  let response = await cache.match(cachePath);

  if (response) {
    console.log(`[SW] Cache hit: ${request.url} -> ${cachePath}`);

    // Refresh cache in background if stale (stale-while-revalidate)
    if (route.revalidate) {
      fetchAndCache(cachePath, cache);
    }

    return response;
  }

  // Cache miss - fetch and cache
  console.log(`[SW] Cache miss: ${request.url} -> ${cachePath}`);

  response = await fetchAndCache(cachePath, cache);

  if (response) {
    return response;
  }

  // Fallback to network request for original URL
  return fetch(request);
}

/**
 * Fetch a resource and add it to cache
 */
async function fetchAndCache(url, cache) {
  try {
    const response = await fetch(url);

    if (response.ok) {
      // Clone response since it can only be consumed once
      cache.put(url, response.clone());
      return response;
    }
  } catch (err) {
    console.error(`[SW] Fetch failed for ${url}:`, err);
  }

  return null;
}
