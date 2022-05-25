const path = require('path')

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
       test: /\.html/,
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
    filename: 'main.js',
    path: path.resolve(__dirname, 'dist'),
    clean: true
  },
  mode: 'development',
  devtool: 'source-map',
  devServer: {
    static: './dist',
  }
}
