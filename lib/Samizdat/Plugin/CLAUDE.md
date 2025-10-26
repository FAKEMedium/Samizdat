# Samizdat plugins

This drectory has plugins common for the whole application, as well as extras that can be added in the
extraplugins section of the configuration.

## A plugin typically

- Defines a single helper based on one model
- Routes for the sub-application, descending from most to least specific
- Needs to be loaded in configuration after dependent plugins
- Uses different route shortcuts for public/authorized actions (\$r->home and \$r->manager),
  which allows for less typing in route definitions
- Use names on routes so controller and templates can use the url_for helper
- Aligns routes routes vertically for readability

## Helpers

- Ideally only pass configuration -> manager -> exampleplugin
- May have to pass other helpers, like databases or utilities

## Static cache and making optimized

The Web plugin catches the after-render hook of Mojolicious. Some inserts and cleanups of the DOM are made.
Most html are placed in the public directory to be picked up by Nginx finstead next time.
Image requests triggers conversion and resizing to srcset variants