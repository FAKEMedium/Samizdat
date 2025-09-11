const fs = require('fs');
const pkg = require('./package.json');
const path = require('path');
const glob = require('glob');
const merge = require('webpack-merge');
const autoprefixer = require('autoprefixer');
const TerserPlugin = require('terser-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');
const { PurgeCSSPlugin } = require("purgecss-webpack-plugin");
const srcDir = path.resolve(__dirname, 'src');
const PATHS = {
  public: path.join(__dirname, "public")
};
const isDev = process.env.MOJO_MODE === 'development';
const config = {
  devtool: 'source-map',
  output: {
    filename: isDev ? '[name].[chunkhash].js' : '[name].js',
    path: path.resolve(__dirname, 'public/assets'),
    publicPath: ''
  },
  mode: isDev ? 'development' : 'production',
  entry: {},
  plugins: [],
  module: {rules: []},
  optimization: {
    minimizer: [],
    splitChunks: {
      cacheGroups: {
        tiptap: {
          test: /[\\/]node_modules[\\/]@tiptap/,
          name: 'editor',
          chunks: 'all',
          enforce: true
        }
      }
    }
  }
};

config.entry['samizdat'] = './src/js/samizdat.js';
config.entry['authenticated'] = './src/js/authenticated.js';
config.entry['sw'] = './src/js/sw.js';
// config.entry['editor'] = './src/js/editor.js'; // TipTap editor - commented out, using simple-editor instead
config.entry['simple-editor'] = './src/js/simple-editor.js';

if (!isDev) {
  config.optimization.minimizer.push(
    new TerserPlugin({parallel: true, terserOptions: {}})
  );
  config.optimization.minimizer.push(
    new CssMinimizerPlugin({})
  );
}

config.module.rules.push({
  test: /\.js$/,
  exclude: /node_modules/,
  use: {
    loader: 'babel-loader', options: {
      presets: [['@babel/preset-env', {
        targets: {
          browsers: ['last 2 versions', 'not dead', '> 1%', 'not ie 11']
        },
        useBuiltIns: false,
        modules: false
      }]]
    }
  }
});

config.module.rules.push({
  test: /\.s(c|a)ss$/,
  use: [
    {loader: MiniCssExtractPlugin.loader},
    {loader: 'css-loader', options: {sourceMap: true, url: false}},
    {loader: 'postcss-loader', options: {postcssOptions: {plugins: () => [autoprefixer]}}},
    {loader: 'sass-loader', options: {sourceMap: true}}
  ]
});

config.module.rules.push({
  test: /\.css$/,
  use: [
    {loader: MiniCssExtractPlugin.loader},
    {loader: 'css-loader', options: {sourceMap: true, url: false}}
  ]
});

config.plugins.push(
  new MiniCssExtractPlugin({
    filename: isDev ? '[name].[chunkhash].css' : '[name].css',
    chunkFilename: '[id].css'
  })
);

config.plugins.push(
  new PurgeCSSPlugin({
    paths: [
      ...glob.sync(`${PATHS.public}/**/*.html`, { nodir: true }),
      ...glob.sync(`${__dirname}/src/public/**/*.md`, { nodir: true }),
      ...glob.sync(`${__dirname}/templates/**/*.html.ep`, { nodir: true }),
      ...glob.sync(`${__dirname}/templates/**/*.js`, { nodir: true }),
      ...glob.sync(`${__dirname}/src/js/*.js`, { nodir: true })
    ],
    safelist: {
      standard: [
        'active',
        'show',
        'hiding',
        'collapsing',
        'modal-backdrop',
        'modal-open',
        'fade',
        'in'
      ]
    }
  })
);

module.exports = config;