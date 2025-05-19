# Nginx Internationalization (i18n) Configuration

This directory contains a special Nginx configuration that enables serving language-specific content based on user preference. The configuration allows Nginx to check a user's language cookie and serve the appropriate localized content.

## How It Works

The configuration works by:

1. Reading the `language` cookie from visitor requests
2. Mapping the cookie value to a file suffix (e.g., `_sv` for Swedish)
3. Trying to serve files with that suffix before falling back to default files

For example, if a user has their language set to Swedish (`language=sv` cookie) and requests `/about/`:

1. Nginx will first check for `/about_sv.html`
2. Then `/about_sv.md`
3. Then `/about/_sv.html`
4. Then `/about/index_sv.html`
5. If none of these exist, it will fall back to `/about/` and `/about/index.html`
6. If still not found, the request is passed to the Mojolicious backend

## Installation

To enable the internationalized content serving:

1. Copy the configuration file to your Nginx sites-available directory:
   ```bash
   sudo cp samizdat-i18n.conf /etc/nginx/sites-available/
   ```

2. If you're replacing the standard configuration, remove the old symlink:
   ```bash
   sudo rm /etc/nginx/sites-enabled/samizdat.conf
   ```

3. Create a symlink to enable the new configuration:
   ```bash
   sudo ln -s /etc/nginx/sites-available/samizdat-i18n.conf /etc/nginx/sites-enabled/
   ```

4. Test the configuration:
   ```bash
   sudo nginx -t
   ```

5. Reload Nginx:
   ```bash
   sudo systemctl reload nginx
   ```

## File Naming Conventions

For this configuration to work correctly, follow these naming conventions for your content files:

- Default (English) content: `filename.html`, `filename.md`, or `directory/index.html`
- Localized content: `filename_LANG.html`, `filename_LANG.md`, or `directory/index_LANG.html`

Where `LANG` is the language code that matches the cookie value (e.g., `sv`, `de`, `fr`).

## Adding More Languages

To add support for additional languages:

1. Edit the `map` directive in the configuration file to add the new language code and its corresponding suffix
2. Create content files with the appropriate suffix
3. Ensure the language is properly supported in the Samizdat application's language selector

## Testing

To test the configuration, you can manually set the language cookie in your browser:

1. Open your browser's developer tools (F12)
2. Go to the Console tab
3. Set the cookie with: `document.cookie = "language=sv; path=/; max-age=31536000"`
4. Refresh the page to see the Swedish version (if available)

You can replace `sv` with any supported language code to test different languages.