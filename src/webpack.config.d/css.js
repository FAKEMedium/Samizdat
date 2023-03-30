const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const CssMinimizerPlugin = require("css-minimizer-webpack-plugin")
const autoprefixer = require("autoprefixer")
const { PurgeCSSPlugin } = require("purgecss-webpack-plugin")
const glob = require('glob')
const path = require('path')
const PATHS = {
    public: path.join(__dirname, "../../public"),
}
module.exports = function (config, {isDev}) {
    config.plugins.push(new PurgeCSSPlugin({paths: glob.sync(`${PATHS.public}/**/*.html`, { nodir: true })}))
    if (!isDev) config.optimization.minimizer.push(new CssMinimizerPlugin({}))
    config.plugins.push(new MiniCssExtractPlugin({
        filename: isDev ? '../css/[name].css' : '../css/[name].css',
        chunkFilename: "../css/[id].css"
    }))
    config.module.rules.push({
        test: /\.css$/,
        use: [
            {loader: MiniCssExtractPlugin.loader},
            {loader: 'css-loader', options: {sourceMap: true, url: false}},
            {loader: 'postcss-loader', options: {postcssOptions: {plugins: () => [autoprefixer]}}}
        ]
    });
};