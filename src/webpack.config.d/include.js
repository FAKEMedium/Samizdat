module.exports = function(config, opts) {
  require('./js')(config, opts);
  require('./css')(config, opts);
  require('./sass')(config, opts);
  require('./svg')(config, opts);
};
