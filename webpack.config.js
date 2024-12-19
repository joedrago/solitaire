const path = require("path")
const HtmlWebpackPlugin = require("html-webpack-plugin")
const webpack = require("webpack")

const calcVersion = () => {
    const now = new Date()
    const zp = (n) => {
        if (n < 10) {
            return "0" + String(n)
        }
        return String(n)
    }
    return `"${now.getFullYear()}${zp(now.getMonth())}${zp(now.getDate())}${zp(now.getHours())}${zp(now.getMinutes())}"`
}

module.exports = {
    module: {
        rules: [
            {
                test: /\.(png|svg|webmanifest)/,
                type: "asset/resource",
                generator: {
                    filename: "[name][ext]"
                }
            }
        ]
    },
    resolve: {
        extensions: [".js"]
    },
    entry: "./src/boot.js",
    output: {
        filename: "main-[fullhash].js",
        path: path.resolve(__dirname, "dist"),
        clean: true
    },
    mode: "development",
    devtool: "source-map",
    devServer: {
        static: "./dist"
    },
    plugins: [
        new HtmlWebpackPlugin({
            template: "src/index.html",
            filename: "index.html"
        }),

        new webpack.DefinePlugin({
            // WEBPACK_BUILD_VERSION: webpack.DefinePlugin.runtimeValue(calcVersion)
            WEBPACK_BUILD_VERSION: '"' + process.env.npm_package_version + '"'
        })
    ]
}
