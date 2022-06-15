const path = require('path')
const HtmlWebpackPlugin = require('html-webpack-plugin')
const webpack = require('webpack')

const calcVersion = () => {
  const now = new Date()
  const zp = (n) => {
    if (n < 10) {
      return "0" + String(n)
    }
    return String(n)
  }
  return `"${now.getFullYear()}${zp(now.getMonth())}${zp(now.getDate())}${zp(now.getHours())}${zp(now.getMinutes())}"`;
}

module.exports = {
  module: {
    rules: [
      {
        test: /\.coffee$/,
        loader: "coffee-loader",
        options: {
          sourceMap: true
        }
      },
      {
        test: /\.(png|svg|webmanifest)/,
        type: 'asset/resource',
        generator: {
          filename: '[name][ext]'
        }
      }
    ],
  },
  resolve: {
      extensions: [ '.coffee', '.js' ]
  },
  entry: './src/boot.coffee',
  output: {
    filename: 'main-[fullhash].js',
    path: path.resolve(__dirname, 'dist'),
    clean: true
  },
  mode: 'development',
  devtool: 'source-map',
  devServer: {
    static: './dist',
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
