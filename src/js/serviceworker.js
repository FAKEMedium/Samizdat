// Service Worker registration (using URL from body data attribute)
const swUrl = document.body?.dataset?.swUrl;
if ('serviceWorker' in navigator && swUrl) {
    // Unregister any stale service workers at wrong URLs
    navigator.serviceWorker.getRegistrations().then(function (registrations) {
        for (const reg of registrations) {
            if (reg.active && reg.active.scriptURL !== new URL(swUrl, location.href).href) {
                reg.unregister();
            }
        }
    });

    navigator.serviceWorker
        .register(swUrl, { scope: '/' })
        .then(function (reg) {
            // console.log('Service worker registration successful');
        })
        .catch(function (err) {
            console.error('Service worker registration failed:', err);
        });
}
