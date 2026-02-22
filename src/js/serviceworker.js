// Service Worker registration (using URL from body data attribute)
const swUrl = document.body?.dataset?.swUrl;
if ('serviceWorker' in navigator && swUrl) {
    navigator.serviceWorker
        .register(swUrl, { scope: '/' })
        .then(function (reg) {
            // console.log('Service worker registration successful');
        })
        .catch(function (err) {
            console.error('Service worker registration failed:', err);
        });
}
