if ('serviceWorker' in navigator) {
    navigator
        .serviceWorker
        .register(
            '/js/sw.js'
        )
        .then(function (reg) {
            console.log('Service worker registration successful');
        });
}