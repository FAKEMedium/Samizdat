if ('serviceWorker' in navigator) {
    navigator
        .serviceWorker
        .register(
            '/assets/sw.js'
        )
        .then(function (reg) {
            console.log('Service worker registration successful');
        });
}