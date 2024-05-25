import 'sprintf-js';
!function() {
  'use strict';

  function shortbytes(bytes) {
    return (bytes < 1024) ? sprintf("%d bytes", bytes)

      : (bytes < (1024*10)) ? sprintf("%.2f kB", (bytes / (1024.0)))
        : (bytes < (1024*100)) ? sprintf("%.1f kB", (bytes / (1024.0)))
          : (bytes < (1024*1024)) ? sprintf("%.0f kB", (bytes / (1024.0)))

            : (bytes < (1024*1024*10)) ? sprintf("%.2f MB", (bytes / (1024.0*1024)))
              : (bytes < (1024*1024*100)) ? sprintf("%.1f MB", (bytes / (1024.0*1024)))
                : (bytes < (1024*1024*1024)) ? sprintf("%.0f MB", (bytes / (1024.0*1024)))

                  : (bytes < (1024*1024*1024*10)) ? sprintf("%.2f GB", (bytes / (1024.0*1024*1024)))
                    : (bytes < (1024*1024*1024*100)) ? sprintf("%.1f GB", (bytes / (1024.0*1024*1024)))
                      : (bytes < (1024*1024*1024*1024)) ? sprintf("%.0f GB", (bytes / (1024.0*1024*1024)))

                        : (bytes < (1024*1024*1024*1024*10)) ? sprintf("%.2f TB", (bytes / (1024.0*1024*1024*1024)))
                          : (bytes < (1024*1024*1024*1024*100)) ? sprintf("%.1f TB", (bytes / (1024.0*1024*1024*1024)))
                            : (bytes < (1024*1024*1024*1024*1024)) ? sprintf("%.0f TB", (bytes / (1024.0*1024*1024*1024)))

                              : (bytes < (1024*1024*1024*1024*1024*10)) ? sprintf("%.2f PB", (bytes / (1024.0*1024*1024*1024*1024)))
                                : (bytes < (1024*1024*1024*1024*1024*100)) ? sprintf("%.1f PB", (bytes / (1024.0*1024*1024*1024*1024)))
                                  : (bytes < (1024*1024*1024*1024*1024*1024)) ? sprintf("%.0f PB", (bytes / (1024.0*1024*1024*1024*1024)))

                                    : (bytes < (1024*1024*1024*1024*1024*1024*10)) ? sprintf("%.2f EB", (bytes / (1024.0*1024*1024*1024*1024*1024)))
                                      : (bytes < (1024*1024*1024*1024*1024*1024*100)) ? sprintf("%.1f EB", (bytes / (1024.0*1024*1024*1024*1024*1024)))
                                        : (bytes < (1024*1024*1024*1024*1024*1024*1024)) ? sprintf("%.0f EB", (bytes / (1024.0*1024*1024*1024*1024*1024)))

                                          : 'More than a zettabyte...';
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