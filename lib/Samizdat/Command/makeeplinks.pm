package Samizdat::Command::makeeplinks;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::File 'path';
use File::Spec;

has description => 'Recursively create relative symlinks for .js, .tex, and .css files';
has usage       => "Usage: APPLICATION makeeplinks [DIRECTORY]\n";

sub run ($self, @args) {
  # Default directory is 'templates'
  my $dir = $args[0] // 'templates';

  # Ensure the directory exists
  my $base = path($dir);
  die "Directory '$dir' does not exist\n" unless -d $base;

  # Recursively process the directory
  $base->list_tree->each(sub ($file, $num) {
    # Skip if it's not a regular file
    return unless -f $file;

    # Handle `.js`, `.tex`, and `.css` files for symlink creation
    if ($file->basename =~ /\.(js|tex|css)$/) {
      my $target = $file->realpath->to_string;    # Absolute path of the target file
      my $link   = path($file . '.ep')->to_string; # Symlink name as a string

      # Compute relative path from symlink to the target
      my $rel_path = File::Spec->abs2rel($target, path($link)->dirname->to_string);

      # Create the symlink
      if (symlink $rel_path, $link) {
        $self->app->log->info("Created symlink: $link -> $rel_path");
      } else {
        $self->app->log->error("Failed to create symlink: $link -> $rel_path: $!");
      }
    }
  });

  $self->app->log->info("Symlink creation completed.");
}

1;
