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
const sharedSrc = process.env.SAMIZDAT_SHARED_SRC || '/usr/local/share/samizdat/src';
const siteSrc = process.env.SAMIZDAT_SRC || path.resolve(__dirname, 'src');
// Use local src as shared during development (when shared doesn't exist)
const effectiveSharedSrc = fs.existsSync(sharedSrc) ? sharedSrc : path.resolve(__dirname, 'src');
const PATHS = {
  public: path.join(__dirname, "public"),
  sharedSrc: effectiveSharedSrc,
  siteSrc: siteSrc
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
  resolve: {
    alias: {
      '@site': PATHS.siteSrc,
      '@shared': PATHS.sharedSrc
    }
  },
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

config.entry['samizdat'] = `${PATHS.sharedSrc}/js/samizdat.js`;
config.entry['authenticated'] = `${PATHS.sharedSrc}/js/authenticated.js`;
config.entry['sw'] = `${PATHS.sharedSrc}/js/sw.js`;
// config.entry['editor'] = `${PATHS.sharedSrc}/js/editor.js`; // TipTap editor - commented out, using simple-editor instead
// config.entry['simple-editor'] = `${PATHS.sharedSrc}/js/simple-editor.js`;
config.entry['tiptap'] = `${PATHS.sharedSrc}/js/tiptap.js`;

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
    loader: 'babel-loader'
  }
});

config.module.rules.push({
  test: /\.s(c|a)ss$/,
  use: [
    {loader: MiniCssExtractPlugin.loader},
    {loader: 'css-loader', options: {sourceMap: true, url: false}},
    {loader: 'postcss-loader', options: {postcssOptions: {plugins: () => [autoprefixer]}}},
    {loader: 'sass-loader', options: {sourceMap: true, api: 'modern', additionalData: (content, loaderContext) => {
      // For samizdat.scss, replace @import "local" with site-specific path
      if (loaderContext.resourcePath.endsWith('samizdat.scss')) {
        return content.replace('@import "local";', `@import "${PATHS.siteSrc}/scss/local.scss";`);
      }
      return content;
    }, sassOptions: { quietDeps: true, silenceDeprecations: ['import'], loadPaths: [PATHS.siteSrc + '/scss', PATHS.sharedSrc + '/scss', path.resolve(__dirname, 'node_modules'), '/usr/local/share/samizdat/node_modules']}}}
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

// PurgeCSS to remove unused CSS in production builds
config.plugins.push(
  new PurgeCSSPlugin({
    paths: [
      ...glob.sync(`${PATHS.public}/**/*.html`, { nodir: true }),
      ...glob.sync(`${PATHS.siteSrc}/public/**/*.md`, { nodir: true }),
      ...glob.sync(`${PATHS.siteSrc}/public/**/*.svg`, { nodir: true }),
      ...glob.sync(`${PATHS.siteSrc}/svg/**/*.svg`, { nodir: true }),
      ...glob.sync(`${PATHS.sharedSrc}/svg/**/*.svg`, { nodir: true }),
      ...glob.sync(`${__dirname}/templates/**/*.html.ep`, { nodir: true }),
      ...glob.sync(`${__dirname}/templates/**/*.js`, { nodir: true }),
      ...glob.sync(`${__dirname}/templates/**/*.js.ep`, { nodir: true }),
      ...glob.sync(`${PATHS.sharedSrc}/js/*.js`, { nodir: true }),
      ...glob.sync(`${PATHS.siteSrc}/js/*.js`, { nodir: true })
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