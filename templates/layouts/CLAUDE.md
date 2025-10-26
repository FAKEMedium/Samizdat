# Samizdat layouts

The default layout for the project is 'bootstrap'. Some features of 'bootstrap' layout include:

- Responsive design for mobile and desktop
- Uses special stash web => \$web
- Lay has 8 + 4 columns if \$weh->{sidebar} exists, otherwise 12 columns
- Predefined element universalmodal for popups like login, etc
- Predefined element toast-messages for notifications
- Included chunks for specific parts to keep the file lean and clean
- Areas for custom inlined CSS and JS coming from templates/**/*.js files
- Symbol definitions area for SVG files included by the Samizdat icon helper
- Inlined CSS is wrapped into style tag in the head for better performance
- Inlined js is wrapped into DOMContentLoaded event listener to make sure DOM is ready and external libraries are loaded
- Proper indentation (2 spaces) for better readability and overview
- leftlinks and rightlinks areas for ads and banners
- Localization, even right-to-left (RTL) support
- No third party dependencies! Everything sits locally

## Other layouts

- modal, for modals with support for inlined CSS and JS
- default.mail, for email with support for organization logo and inlined CSS