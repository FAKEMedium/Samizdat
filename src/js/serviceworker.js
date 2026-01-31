// Service Worker registration (using URL from body data attribute)
const swUrl = document.body?.dataset?.swUrl;
if ('serviceWorker' in navigator && swUrl) {
    navigator.serviceWorker
        .register(swUrl)
        .then(function (reg) {
            // console.log('Service worker registration successful');
        });
}