# Samizdat controllers

Controllers shall only pass data as json. GET requests that don't accept application/json are rendered for
the static cache in the public directory. Templates are mostly called **/index.html.ep, and are accompanied
by an index.js.ep that gets inlined in the final result.

A special stash web => \$web exists that is used to pass variables for templating.

The access handler defined in the Account handler is used when dealing with json data.