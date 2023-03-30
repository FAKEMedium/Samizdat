const fs = require('fs');
const pkg = require('./package.json');
const path = require('path');
const srcDir = path.resolve(__dirname, 'src');
const isDev = process.env.NODE_ENV !== 'production';

const config = {
  entry: {},
  mode: isDev ? 'development' : 'production',
  module: {rules: []},
  optimization: {minimizer: []},
  output: {},
  plugins: [],
};

config.output.filename = isDev ? '[name].js' : '[name].js';
config.output.path = path.resolve(__dirname, 'public/js');
config.output.publicPath = '';

const entry = path.resolve(srcDir, 'js/samizdat.js');
if (fs.existsSync(entry)) config.entry[pkg.name.replace(/\W+/g, '-')] = entry;

const includeFile = path.resolve(srcDir, 'webpack.config.d', 'include.js');
if (fs.existsSync(includeFile)) require(includeFile)(config, {isDev});

module.exports = config;
