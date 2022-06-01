const path = require('path')
const HtmlWebpackPlugin = require('html-webpack-plugin')

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
  plugins: [new HtmlWebpackPlugin({
    template: "src/index.html",
    filename: "index.html"
  })]
}
