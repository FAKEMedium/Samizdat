---
description: TipTap markdown editor setup for Samizdat inline editing
keywords:
  - TipTap
  - markdown
  - editor
  - WYSIWYG
  - inline editing
---

# TipTap Editor

Samizdat uses [TipTap](https://tiptap.dev/) for inline markdown editing. TipTap is a headless, framework-agnostic rich text editor built on ProseMirror.

## Dependencies

```bash
npm install @tiptap/core @tiptap/starter-kit @tiptap/extension-image @tiptap/extension-table tiptap-markdown
```

## Webpack Configuration

TipTap is bundled as a separate entry point to enable code splitting:

```javascript
// webpack.config.js
config.entry['tiptap'] = `${PATHS.sharedSrc}/js/tiptap.js`;

config.optimization.splitChunks = {
  cacheGroups: {
    tiptap: {
      test: /[\\/]node_modules[\\/]@tiptap/,
      name: 'editor',
      chunks: 'all',
      enforce: true
    }
  }
};
```

This creates two files:
- `editor.js` - TipTap core and extensions (vendor chunk)
- `tiptap.js` - Application code

## Architecture

### Source Content API

The `/manager/web/source` endpoint returns raw markdown for editing:

```json
{
  "success": true,
  "content": {
    "main": {
      "title": "Page Title",
      "content": "Markdown content..."
    },
    "sidecards": [
      {
        "title": "Card Title",
        "content": "Card markdown...",
        "src": "01-card.md"
      }
    ]
  }
}
```

### Markdown Storage

Content is stored as markdown in the database and converted to HTML only at render time:

1. **Editing**: Raw markdown fetched via source API
2. **Saving**: Markdown serialized via `editor.storage.markdown.getMarkdown()`
3. **Display**: Converted to HTML via `Text::MultiMarkdown`

### HTML-to-Markdown Conversion

For legacy HTML content, Pandoc converts to GFM (GitHub Flavored Markdown):

```perl
my $pid = open2($reader, $writer, 'pandoc', '-f', 'html', '-t', 'gfm-pipe_tables');
```

Tables remain as HTML (more flexible than pipe tables).

## Extensions Used

- **StarterKit** - Basic formatting (bold, italic, lists, etc.)
- **Image** - Image support with `img-fluid` class
- **TableKit** - Table editing support
- **Markdown** - tiptap-markdown for serialization

## Template Integration

Add `data-source` attribute for the source API URL:

```html
<div id="thecontent"
     class="editable"
     data-source="<%== url_for('web_source_root') %>">
```

## Usage

```javascript
// Enter edit mode
await window.tiptapMarkdown.enterEditMode();

// Get markdown content
const content = window.tiptapMarkdown.getContent(true);

// Exit and restore original
window.tiptapMarkdown.exitEditMode(false);

// Exit and keep changes
window.tiptapMarkdown.exitEditMode(true);
```
