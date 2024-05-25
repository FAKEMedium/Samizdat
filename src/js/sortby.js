/**
 * Adapted from an answer by Eneko Alonso, https://stackoverflow.com/a/32773923
 */

(function(){
  let keyPaths = [];

  let saveKeyPath = function(path) {
    keyPaths.push({
      sign: (path[0] === '+' || path[0] === '-')? parseInt(path.shift()+1) : 1,
      path: path
    });
  };

  let valueOf = function(object, path) {
    let ptr = object;
    for (let i=0,l=path.length; i<l; i++) ptr = ptr[path[i]];
    return ptr;
  };

  let comparer = function(a, b) {
    for (let i = 0, l = keyPaths.length; i < l; i++) {
      let aVal = valueOf(a, keyPaths[i].path);
      let bVal = valueOf(b, keyPaths[i].path);
      if (aVal > bVal) return keyPaths[i].sign;
      if (aVal < bVal) return -keyPaths[i].sign;
    }
    return 0;
  };

  Array.prototype.sortBy = function() {
    keyPaths = [];
    for (let i=0,l=arguments.length; i<l; i++) {
      switch (typeof(arguments[i])) {
        case "object": saveKeyPath(arguments[i]); break;
        case "string": saveKeyPath(arguments[i].match(/[+-]|[^.]+/g)); break;
      }
    }
    return this.sort(comparer);
  };

})();