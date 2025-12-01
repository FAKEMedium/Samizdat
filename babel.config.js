module.exports = {
  presets: [
    [
      '@babel/preset-env',
      {
        targets: {
          browsers: ['last 2 versions', 'not dead', '> 1%', 'not ie 11']
        },
        useBuiltIns: false,
        modules: 'auto'
      }
    ]
  ],
  sourceType: 'module'
};
