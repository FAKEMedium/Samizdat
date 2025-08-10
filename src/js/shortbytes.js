!function() {
  'use strict';

  function shortbytes(bytes) {
    if (bytes < 1024) return `${bytes} bytes`;
    
    const units = ['kB', 'MB', 'GB', 'TB', 'PB', 'EB'];
    let unitIndex = 0;
    let size = bytes / 1024;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    if (unitIndex >= units.length) return 'More than a zettabyte...';
    
    // Format with appropriate decimal places
    const decimals = size < 10 ? 2 : size < 100 ? 1 : 0;
    return `${size.toFixed(decimals)} ${units[unitIndex]}`;
  }


  /**
   * export to either browser or node.js
   */
  /* eslint-disable quote-props */
  if (typeof exports !== 'undefined') {
    exports['shortbytes'] = shortbytes;
  }
  if (typeof window !== 'undefined') {
    window['shortbytes'] = shortbytes;

    if (typeof define === 'function' && define['amd']) {
      define(function() {
        return {
          'shortbytes': shortbytes
        }
      });
    }
  }
/* eslint-enable quote-props */}(); // eslint-disable-line