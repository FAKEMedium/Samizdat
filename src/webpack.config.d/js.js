const TerserPlugin = require('terser-webpack-plugin')

module.exports = function(config, {isDev}) {
  if (!isDev) config.optimization.minimizer.push(new TerserPlugin({parallel: true, terserOptions: {}}))

  config.module.rules.push({
    test: /\.js$/,
    exclude: /node_modules/,
    use: {loader: 'babel-loader', options: {plugins: ['@babel/plugin-transform-runtime'], presets: ['@babel/preset-env']}}
  });
};
