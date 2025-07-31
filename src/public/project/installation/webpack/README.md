[description]: # "How Samizdat minimizes assets by using Webpack and PurgeCSS"
[keywords]: # "Webpack,optimization,PurgeCSS,treeshaking"

# Webpack

[Bootstrap](https://getbootstrap.com/) has rather large javascript and css files. With Webpack it's rather easy
to build a custom package, and then remove the parts that aren't used in the project. This makes traffic faster
and lighter, as well as lowering the time to parse and execute code.

* Start [webpack](./webpack/) to minimize files
