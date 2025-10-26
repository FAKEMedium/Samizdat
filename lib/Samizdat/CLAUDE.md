# CLAUE.md, Samizdat main lib

 A recipe for rapid development and try-out of new features

- Set up common stuff in Samizdat.pm
- Add routes add helpers in plugins
- Corresponding models and controllers
- Aim för a single model helper per sub-application
- Try to keep logic in the model to avoid abundance of helpers
- Most tasks should be possible to perform from command line too

The last included plugin, Web, catches non-matched routes and tries them agains the database and the
markdown files in src/public.
