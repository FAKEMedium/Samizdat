// TipTap editor with Markdown support
// Entry point for markdown-based editing

console.log('TipTap module loading...');

import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Image from '@tiptap/extension-image'
import { TableKit } from '@tiptap/extension-table'

// Markdown serialization support
import { Markdown } from 'tiptap-markdown'

console.log('TipTap imports loaded successfully');

/**
 * TipTap Markdown Editor Manager
 * Transforms editable areas into TipTap editors with markdown support
 */
class TipTapMarkdownManager {
  constructor() {
    this.editors = new Map(); // element -> editor instance
    this.originalContent = new Map(); // element -> original HTML for cancel
    this.sourceData = null; // source content from API
    this.isEditMode = false;
  }

  /**
   * Fetch source markdown content from the API
   */
  async fetchSourceContent() {
    const currentPath = window.location.pathname;
    const theContent = document.getElementById('thecontent');

    // Get source URL from data attribute (set by url_for in template)
    const baseSourceUrl = theContent?.dataset.source;
    if (!baseSourceUrl) {
      console.warn('TipTap: No data-source attribute found on #thecontent');
      return null;
    }

    // Append current path to the base source URL
    let sourceUrl = baseSourceUrl;
    if (currentPath && currentPath !== '/') {
      sourceUrl = baseSourceUrl + currentPath;
    }

    console.log(`TipTap: Fetching source from ${sourceUrl}`);

    try {
      const response = await fetch(sourceUrl, {
        method: 'GET',
        headers: { 'Accept': 'application/json' },
        credentials: 'same-origin'
      });

      if (!response.ok) {
        console.warn(`TipTap: Source fetch failed with status ${response.status}`);
        return null;
      }

      const data = await response.json();
      if (data.success) {
        console.log('TipTap: Source content loaded:', data);
        return data.content;
      } else {
        console.warn('TipTap: Source API returned error:', data.error);
        return null;
      }
    } catch (error) {
      console.error('TipTap: Failed to fetch source:', error);
      return null;
    }
  }

  /**
   * Initialize edit mode - transform all .editable elements into TipTap editors
   */
  async enterEditMode() {
    if (this.isEditMode) return;

    // Fetch source markdown content from API
    this.sourceData = await this.fetchSourceContent();

    const editables = document.querySelectorAll('.editable');
    console.log(`TipTap: Entering edit mode, found ${editables.length} editable elements`);

    editables.forEach((element, index) => {
      this.createEditor(element, index);
    });

    this.isEditMode = true;
    document.body.classList.add('edit-mode');
  }

  /**
   * Exit edit mode - destroy editors and optionally restore original content
   */
  exitEditMode(save = false) {
    if (!this.isEditMode) return;

    // Destroy all editors first
    this.editors.forEach((editor, element) => {
      if (!save) {
        // Get the original content before destroying
        const originalHtml = this.originalContent.get(element);
        editor.destroy();
        // Restore original content after destroy
        if (originalHtml !== undefined) {
          element.innerHTML = originalHtml;
        }
      } else {
        // Just destroy, keep the current editor content
        const finalHtml = editor.getHTML();
        editor.destroy();
        element.innerHTML = finalHtml;
      }
    });

    this.editors.clear();
    this.originalContent.clear();
    this.sourceData = null;
    this.isEditMode = false;
    document.body.classList.remove('edit-mode');
  }

  /**
   * Get markdown content for an element from source data
   * @param {string} elementId - The DOM element ID
   * @param {HTMLElement} element - The DOM element (to check parent data-src)
   */
  getSourceMarkdown(elementId, element = null) {
    if (!this.sourceData) return null;

    // Check if it's the main content area
    if (elementId === 'thecontent' || elementId === 'maincontent') {
      return this.sourceData.main?.content || null;
    }

    // Check if it's the main title (headline)
    if (elementId === 'headline' || elementId === 'thetitle' || elementId === 'maintitle') {
      return this.sourceData.main?.title || null;
    }

    // Check sidecards - match by data-src attribute on parent card container
    if (this.sourceData.sidecards && element) {
      // Find the parent card container with data-src attribute
      const cardContainer = element.closest('[data-src]');
      if (cardContainer) {
        const dataSrc = cardContainer.dataset.src;
        console.log(`TipTap: Looking for sidecard with src="${dataSrc}" for element "${elementId}"`);

        for (const card of this.sourceData.sidecards) {
          if (card.src === dataSrc) {
            // Check if we want title or content based on element ID suffix
            if (elementId.endsWith('-title')) {
              console.log(`TipTap: Found sidecard title for ${dataSrc}`);
              return card.title || '';
            } else {
              console.log(`TipTap: Found sidecard content for ${dataSrc}`);
              return card.content || '';
            }
          }
        }
      }
    }

    // Fallback: Check sidecards by element ID patterns
    if (this.sourceData.sidecards) {
      for (const card of this.sourceData.sidecards) {
        // Match elementId against src (with or without .md extension)
        const srcWithoutMd = card.src.replace(/\.md$/, '');
        if (elementId === card.src || elementId === srcWithoutMd ||
            elementId === `${srcWithoutMd}-content` || elementId === `${srcWithoutMd}-title`) {
          if (elementId.endsWith('-title')) {
            return card.title || '';
          }
          return card.content || '';
        }
      }

      // Try numeric index match for sidecard-N pattern
      const indexMatch = elementId.match(/sidecard-?(\d+)/i);
      if (indexMatch) {
        const idx = parseInt(indexMatch[1], 10);
        if (this.sourceData.sidecards[idx]) {
          return this.sourceData.sidecards[idx].content;
        }
      }
    }

    return null;
  }

  /**
   * Create a TipTap editor for an element
   */
  createEditor(element, index) {
    // Store original HTML content for cancel
    this.originalContent.set(element, element.innerHTML);

    // Get the element's ID for save mapping
    const elementId = element.id || `element-${index}`;

    // Determine if this is a title (heading) or content area
    const isTitle = element.classList.contains('title') ||
                    element.tagName.match(/^H[1-6]$/i);

    // Get markdown source if available, otherwise fall back to existing HTML
    let content = this.getSourceMarkdown(elementId, element);
    const hasMarkdownSource = content !== null;

    if (!hasMarkdownSource) {
      // Fall back to element's HTML if no markdown source available
      content = element.innerHTML;
      console.log(`TipTap: No markdown source for ${elementId}, using HTML`);
    } else {
      console.log(`TipTap: Using markdown source for ${elementId}`);
    }

    // Clear the element before creating editor to prevent duplication
    element.innerHTML = '';

    // Create editor with appropriate config
    const editor = new Editor({
      element: element,
      extensions: this.getExtensions(isTitle),
      // Start with empty content - we'll set markdown content after creation
      content: '',
      editorProps: {
        attributes: {
          class: 'tiptap-editor',
          'data-element-id': elementId,
        },
        // Clean up pasted content (Word, etc.)
        transformPastedHTML(html) {
          return html
            .replace(/<o:p>.*?<\/o:p>/gi, '')
            .replace(/class="Mso[^"]*"/gi, '')
            .replace(/style="[^"]*mso-[^"]*"/gi, '')
            .replace(/<!\[if.*?\]>.*?<!\[endif\]>/gi, '')
            .replace(/<xml>.*?<\/xml>/gi, '')
            .replace(/<style>.*?<\/style>/gi, '');
        }
      },
      onCreate: ({ editor }) => {
        console.log(`TipTap: Editor created for ${elementId}`);
        // Set content after editor is ready
        if (content) {
          try {
            if (isTitle) {
              // For titles, set as plain text (no markdown parsing)
              // This avoids wrapping in <p> tags
              editor.commands.setContent(content.trim());
            } else {
              // For content areas, parse markdown
              const parsedContent = editor.storage.markdown.parser.parse(content);
              editor.commands.setContent(parsedContent, false);
            }
            console.log(`TipTap: Content set for ${elementId}`);
          } catch (e) {
            console.error(`TipTap: Failed to set content for ${elementId}:`, e);
            editor.commands.setContent(content);
          }
        }
      },
      onFocus: ({ editor }) => {
        // Mark as active editor
        window.activeMarkdownEditor = editor;
        element.classList.add('editor-focused');
      },
      onBlur: ({ editor }) => {
        element.classList.remove('editor-focused');
      }
    });

    // Store reference
    this.editors.set(element, editor);
    element.dataset.tiptapIndex = index;

    return editor;
  }

  /**
   * Get TipTap extensions based on element type
   */
  getExtensions(isTitle) {
    if (isTitle) {
      // Minimal extensions for titles - text only, no formatting
      return [
        StarterKit.configure({
          heading: false,
          bulletList: false,
          orderedList: false,
          blockquote: false,
          codeBlock: false,
          horizontalRule: false,
          hardBreak: false,
        }),
        Markdown.configure({
          html: false,
          transformPastedText: true,
        }),
      ];
    }

    // Full extensions for content areas
    // Note: tiptap-markdown includes its own Link mark, so we don't add Link separately
    return [
      StarterKit.configure({
        heading: {
          levels: [2, 3, 4, 5, 6], // h1 reserved for page title
        },
      }),
      Image.configure({
        HTMLAttributes: {
          class: 'img-fluid',
        },
      }),
      TableKit.configure({
        resizable: true,
      }),
      Markdown.configure({
        html: true, // Allow HTML in markdown
        linkify: true,
        breaks: false,
        transformPastedText: true,
        transformCopiedText: true,
      }),
    ];
  }

  /**
   * Get content from all editors
   * Returns object with elementId -> markdown content
   */
  getContent(asMarkdown = true) {
    const content = {};

    this.editors.forEach((editor, element) => {
      const elementId = element.id || element.dataset.tiptapIndex;

      if (asMarkdown) {
        // Get markdown using tiptap-markdown extension
        content[elementId] = editor.storage.markdown.getMarkdown();
      } else {
        // Get HTML
        content[elementId] = editor.getHTML();
      }
    });

    return content;
  }

  /**
   * Get content from a specific editor
   */
  getEditorContent(element, asMarkdown = true) {
    const editor = this.editors.get(element);
    if (!editor) return null;

    if (asMarkdown) {
      return editor.storage.markdown.getMarkdown();
    }
    return editor.getHTML();
  }

  /**
   * Set content for a specific editor
   */
  setEditorContent(element, content, isMarkdown = true) {
    const editor = this.editors.get(element);
    if (!editor) return;

    if (isMarkdown) {
      // Set from markdown
      editor.commands.setContent(content);
    } else {
      editor.commands.setContent(content);
    }
  }
}

// Create global instance immediately
try {
  window.tiptapMarkdown = new TipTapMarkdownManager();
  console.log('TipTap markdown manager created:', window.tiptapMarkdown);
} catch (e) {
  console.error('Failed to create TipTap markdown manager:', e);
}

// Export for module usage
export { TipTapMarkdownManager };

// Add some basic styles
const style = document.createElement('style');
style.textContent = `
  .tiptap-editor {
    outline: none;
  }
  .tiptap-editor:focus {
    outline: none;
  }
  .edit-mode .editable {
    border: 2px dashed #007bff;
    padding: 0.5rem;
    min-height: 2rem;
  }
  .edit-mode .editable.editor-focused {
    border-color: #28a745;
    border-style: solid;
  }
  .edit-mode .editable.title {
    border-color: #ffc107;
  }
  .tiptap-editor p.is-editor-empty:first-child::before {
    color: #adb5bd;
    content: attr(data-placeholder);
    float: left;
    height: 0;
    pointer-events: none;
  }
`;
document.head.appendChild(style);

console.log('TipTap Markdown editor loaded');
