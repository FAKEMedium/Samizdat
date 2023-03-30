const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const OptimizeCSSAssetsPlugin = require('css-minimizer-webpack-plugin')
const autoprefixer = require('autoprefixer')

module.exports = function(config, {isDev}) {
  if (!isDev) config.optimization.minimizer.push(new OptimizeCSSAssetsPlugin({}));
  config.plugins.push(new MiniCssExtractPlugin({filename: isDev ? '../css/[name].css' : '../css/[name].css', chunkFilename: "../css/[id].css"}));
  config.module.rules.push({
    test: /\.s(c|a)ss$/,
    use: [
      {loader: MiniCssExtractPlugin.loader},
      {loader: 'css-loader', options: {sourceMap: true, url: false}},
      {loader: 'postcss-loader', options: {postcssOptions: {plugins: () => [autoprefixer]}}},
      {loader: 'sass-loader', options: {sourceMap: true}}
    ]
  });
};
