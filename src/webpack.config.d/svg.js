module.exports = function (config, {isDev}) {
    config.module.rules.push({
        mimetype: 'image/svg+xml',
        scheme: 'data',
        type: 'asset/resource',
        generator: {filename: '../media/icons/[hash].svg'}
    });
};
