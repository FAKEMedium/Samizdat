package Samizdat::Plugin::Shortbytes;

use Mojo::Base 'Mojolicious::Plugin', -signatures;


sub register ($self, $app, $conf) {

  $app->helper(
    shortbytes => sub ($c, $bytes) {
      my $shortbytes = ($bytes < 1024) ? sprintf("%d bytes", $bytes)
        : ($bytes < (1024*1024)) ? sprintf("%.0f kB", ($bytes / (1024)))
        : ($bytes < (1024*1024*10)) ? sprintf("%.2f MB", ($bytes / (1024*1024)))
        : ($bytes < (1024*1024*100)) ? sprintf("%.1f MB", ($bytes / (1024*1024)))
        : ($bytes < (1024*1024*1024)) ? sprintf("%.0f MB", ($bytes / (1024*1024)))
        : ($bytes < (1024*1024*1024*10)) ? sprintf("%.2f GB", ($bytes / (1024*1024*1024)))
        : ($bytes < (1024*1024*1024*100)) ? sprintf("%.1f GB", ($bytes / (1024*1024*1024)))
        : ($bytes < (1024*1024*1024*1024)) ? sprintf("%.0f GB", ($bytes / (1024*1024*1024)))
        : ($bytes < (1024*1024*1024*1024*100)) ? sprintf("%.1f TB", ($bytes / (1024*1024*1024*1024)))
        : ($bytes < (1024*1024*1024*1024*1024)) ? sprintf("%f TB", ($bytes / (1024*1024*1024*1024)))
        : ($bytes < (1024*1024*1024*1024*1024*1024)) ? sprintf("%.1f PB", ($bytes / (1024*1024*1024*1024*1024)))
        : ($bytes < (1024*1024*1024*1024*1024*1024)) ? sprintf("%f PB", ($bytes / (1024*1024*1024*1024*1024)))
        : 'Too big';
    }
  );
}


1;