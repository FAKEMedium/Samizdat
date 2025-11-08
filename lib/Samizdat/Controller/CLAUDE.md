# Samizdat controllers

Controllers shall only pass data as json. GET requests that don't accept application/json are rendered for
the static cache in the public directory. Templates are mostly called **/index.html.ep, and are accompanied
by an index.js.ep that gets inlined in the final result.

A special stash web => \$web exists that is used to pass variables for templating.

The access handler defined in the Account handler is used when dealing with json data.

## Static cache path override

When a URL contains dynamic data (like domain names, user IDs, or handles), set the `docpath` stash variable
to override the default cache file location. This prevents creating separate cached files for each dynamic value.

Example:
```perl
# Without docpath: /realtimeregister/domains/alipang.net creates public/realtimeregister/domains/alipang.net/index.html
# With docpath: All domains use the same cached file at public/realtimeregister/domains/domain/index.html
$self->stash(docpath => '/realtimeregister/domains/domain/index.html');
```

This pattern is essential for routes with dynamic parameters that serve the same template structure.