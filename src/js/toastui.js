// Toast UI Editor with GFM Markdown support
// Entry point for markdown-based editing

console.log('Toast UI Editor module loading...');

import '@toast-ui/editor/dist/toastui-editor.css';
import { Editor } from '@toast-ui/editor';

console.log('Toast UI imports loaded successfully');

/**
 * Remove soft line breaks (word wrap) while preserving paragraph breaks
 * @param {string} text - Markdown text with soft line breaks
 * @returns {string} - Text with soft breaks removed
 */
function unwrapSoftBreaks(text) {
  if (!text) return text;

  // GFM: two trailing spaces + newline = hard break (<br>), preserve these
  // GFM: tables use spaces for alignment, preserve those too
  // Soft breaks (word wrap at ~80 chars) should be unwrapped
  return text
    // Normalize line endings
    .replace(/\r\n/g, '\n')
    // Unwrap soft breaks: newline NOT preceded by two spaces, NOT followed by special chars
    // Keep breaks: after "  " (hard break), before #-*>|`<[ or digits, double newlines
    .replace(/([^ ])\n(?![\n#\-*>|\d`<\[])/g, '$1 ')
    .trim();
}

/**
 * Toast UI Markdown Editor Manager
 * Transforms editable areas into Toast UI editors with markdown support
 */
class ToastUIMarkdownManager {
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
      console.warn('ToastUI: No data-source attribute found on #thecontent');
      return null;
    }

    // Append current path to the base source URL
    let sourceUrl = baseSourceUrl;
    if (currentPath && currentPath !== '/') {
      sourceUrl = baseSourceUrl + currentPath;
    }

    console.log(`ToastUI: Fetching source from ${sourceUrl}`);

    try {
      const response = await fetch(sourceUrl, {
        method: 'GET',
        headers: { 'Accept': 'application/json' },
        credentials: 'same-origin'
      });

      if (!response.ok) {
        console.warn(`ToastUI: Source fetch failed with status ${response.status}`);
        return null;
      }

      const data = await response.json();
      if (data.success) {
        console.log('ToastUI: Source content loaded:', data);
        return data.content;
      } else {
        console.warn('ToastUI: Source API returned error:', data.error);
        return null;
      }
    } catch (error) {
      console.error('ToastUI: Failed to fetch source:', error);
      return null;
    }
  }

  /**
   * Initialize edit mode - transform all .editable elements into Toast UI editors
   */
  async enterEditMode() {
    if (this.isEditMode) return;

    // Fetch source markdown content from API
    this.sourceData = await this.fetchSourceContent();

    const editables = document.querySelectorAll('.editable');
    console.log(`ToastUI: Entering edit mode, found ${editables.length} editable elements`);

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

    this.editors.forEach((editor, element) => {
      if (!save) {
        const originalHtml = this.originalContent.get(element);
        editor.destroy();
        if (originalHtml !== undefined) {
          element.innerHTML = originalHtml;
        }
      } else {
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
   */
  getSourceMarkdown(elementId, element = null) {
    if (!this.sourceData) return null;

    let content = null;

    if (elementId === 'thecontent' || elementId === 'maincontent') {
      content = this.sourceData.main?.content || null;
    } else if (elementId === 'headline' || elementId === 'thetitle' || elementId === 'maintitle') {
      content = this.sourceData.main?.title || null;
    } else if (this.sourceData.sidecards && element) {
      const cardContainer = element.closest('[data-src]');
      if (cardContainer) {
        const dataSrc = cardContainer.dataset.src;
        for (const card of this.sourceData.sidecards) {
          if (card.src === dataSrc) {
            if (elementId.endsWith('-title')) {
              content = card.title || '';
            } else {
              content = card.content || '';
            }
            break;
          }
        }
      }
    }

    // Unwrap soft line breaks
    return content ? unwrapSoftBreaks(content) : null;
  }

  /**
   * Create a Toast UI editor for an element
   */
  createEditor(element, index) {
    this.originalContent.set(element, element.innerHTML);

    const elementId = element.id || `element-${index}`;
    const isTitle = element.classList.contains('title') ||
                    element.tagName.match(/^H[1-6]$/i);
    const isSidecard = element.classList.contains('card');

    let content = this.getSourceMarkdown(elementId, element);
    const hasMarkdownSource = content !== null;

    if (!hasMarkdownSource) {
      content = element.innerHTML;
      console.log(`ToastUI: No markdown source for ${elementId}, using HTML`);
    } else {
      console.log(`ToastUI: Using markdown source for ${elementId}`);
    }

    // Clear element and create editor container
    element.innerHTML = '';
    const editorContainer = document.createElement('div');
    element.appendChild(editorContainer);

    const editorConfig = {
      el: editorContainer,
      height: 'auto',
      minHeight: '100px',
      initialEditType: 'markdown',
      previewStyle: 'vertical',
      initialValue: content || '',
      usageStatistics: false,
      hooks: {
        addImageBlobHook: async (blob, callback) => {
          // Get image upload URL from data attribute or default
          const theContent = document.getElementById('thecontent');
          const imageUploadUrl = theContent?.dataset.imageUpload || '/manager/web/images';

          const formData = new FormData();
          formData.append('file', blob);

          try {
            const res = await fetch(imageUploadUrl, {
              method: 'POST',
              body: formData,
              credentials: 'same-origin'
            });

            if (!res.ok) {
              console.error('ToastUI: Image upload failed');
              return;
            }

            const data = await res.json();
            callback(data.url, blob.name);
          } catch (error) {
            console.error('ToastUI: Image upload error:', error);
          }
        }
      }
    };

    // Compact config for titles - no toolbar, auto height
    if (isTitle) {
      editorConfig.height = 'auto';
      editorConfig.minHeight = '1em';
      editorConfig.toolbarItems = [];
      editorConfig.previewStyle = 'tab';  // No preview for titles
    }

    // Sidecard config - edit full card markdown
    if (isSidecard) {
      editorConfig.minHeight = '150px';
      // For sidecards, get the full source markdown (title + content combined)
      const dataSrc = element.dataset.src;
      if (this.sourceData?.sidecards && dataSrc) {
        for (const card of this.sourceData.sidecards) {
          if (card.src === dataSrc) {
            // Combine title and content as markdown, unwrap soft breaks
            const title = card.title || '';
            const cardContent = unwrapSoftBreaks(card.content || '');
            content = `# ${title}\n\n${cardContent}`;
            break;
          }
        }
      }
      editorConfig.initialValue = content || '';
    }

    const editor = new Editor(editorConfig);

    this.editors.set(element, editor);
    element.dataset.toastuiIndex = index;

    console.log(`ToastUI: Editor created for ${elementId}`);
    return editor;
  }

  /**
   * Get content from all editors
   */
  getContent(asMarkdown = true) {
    const content = {};

    this.editors.forEach((editor, element) => {
      let elementId = element.id || element.dataset.toastuiIndex;

      // For sidecards with data-src, use src-based key for backend matching
      if (element.classList.contains('card') && element.dataset.src) {
        // Convert "01-samizdat.md" to "01-samizdat-content"
        const srcBase = element.dataset.src.replace(/\.md$/, '');
        elementId = `${srcBase}-content`;
      }

      content[elementId] = asMarkdown ? editor.getMarkdown() : editor.getHTML();
    });

    return content;
  }

  /**
   * Get content from a specific editor
   */
  getEditorContent(element, asMarkdown = true) {
    const editor = this.editors.get(element);
    if (!editor) return null;
    return asMarkdown ? editor.getMarkdown() : editor.getHTML();
  }

  /**
   * Get current editor mode for all editors
   * @returns {string} 'markdown' or 'wysiwyg'
   */
  getCurrentMode() {
    // All editors share the same mode, just check the first one
    const firstEditor = this.editors.values().next().value;
    if (!firstEditor) return 'markdown';
    return firstEditor.isMarkdownMode() ? 'markdown' : 'wysiwyg';
  }

  /**
   * Set editor mode for all editors
   * @param {string} mode - 'markdown' or 'wysiwyg'
   */
  setMode(mode) {
    this.editors.forEach((editor) => {
      if (mode === 'markdown') {
        editor.changeMode('markdown');
      } else {
        editor.changeMode('wysiwyg');
      }
    });
    console.log(`ToastUI: All editors switched to ${mode} mode`);
  }

  /**
   * Toggle between markdown and wysiwyg modes
   * @returns {string} The new mode
   */
  toggleMode() {
    const currentMode = this.getCurrentMode();
    const newMode = currentMode === 'markdown' ? 'wysiwyg' : 'markdown';
    this.setMode(newMode);
    return newMode;
  }

  /**
   * Set preview mode for all editors
   * @param {boolean} showPreview - true to show preview only, false to show editor only
   */
  setPreviewMode(showPreview) {
    document.body.classList.toggle('preview-mode', showPreview);

    // For sidecards, show placeholder content in preview mode
    this.editors.forEach((editor, element) => {
      if (element.classList.contains('card')) {
        const editorContainer = element.querySelector('.toastui-editor-defaultUI');
        if (showPreview) {
          // Hide editor, show placeholder
          if (editorContainer) editorContainer.style.display = 'none';
          let placeholder = element.querySelector('.sidecard-placeholder');
          if (!placeholder) {
            placeholder = document.createElement('div');
            placeholder.className = 'sidecard-placeholder';
            placeholder.innerHTML = `
              <h2 class="card-header p-1 p-sm-2 title">[Title]</h2>
              <div class="card-body p-1 p-sm-2">
                <p class="text-muted">[Card content]</p>
              </div>
            `;
            element.appendChild(placeholder);
          }
          placeholder.style.display = 'block';
        } else {
          // Show editor, hide placeholder
          if (editorContainer) editorContainer.style.display = '';
          const placeholder = element.querySelector('.sidecard-placeholder');
          if (placeholder) placeholder.style.display = 'none';
        }
      }
    });

    console.log(`ToastUI: Preview mode ${showPreview ? 'enabled' : 'disabled'}`);
  }
}

// Create global instance
try {
  window.toastUIMarkdown = new ToastUIMarkdownManager();
  console.log('Toast UI markdown manager created:', window.toastUIMarkdown);
} catch (e) {
  console.error('Failed to create Toast UI markdown manager:', e);
}

export { ToastUIMarkdownManager };

// Add edit-mode styles
const style = document.createElement('style');
style.textContent = `
  .edit-mode .editable {
    border: 2px dashed #007bff;
    padding: 0.5rem;
    min-height: 2rem;
  }
  .edit-mode .editable.title {
    border-color: #ffc107;
  }
  /* Hide built-in mode switch - controlled from headlinenav */
  .toastui-editor-mode-switch {
    display: none !important;
  }
  /* Compact title editors */
  .editable.title .toastui-editor-toolbar,
  h1.editable .toastui-editor-toolbar,
  h2.editable .toastui-editor-toolbar,
  h3.editable .toastui-editor-toolbar,
  h4.editable .toastui-editor-toolbar,
  h5.editable .toastui-editor-toolbar,
  h6.editable .toastui-editor-toolbar {
    display: none !important;
  }
  .editable.title .toastui-editor-defaultUI,
  h1.editable .toastui-editor-defaultUI,
  h2.editable .toastui-editor-defaultUI {
    border: none !important;
  }
  .editable.title .toastui-editor-main,
  h1.editable .toastui-editor-main,
  h2.editable .toastui-editor-main {
    min-height: auto !important;
    height: auto !important;
  }
  .editable.title .toastui-editor-md-container,
  h1.editable .toastui-editor-md-container,
  h2.editable .toastui-editor-md-container {
    height: auto !important;
  }
  .editable.title .ProseMirror,
  h1.editable .ProseMirror,
  h2.editable .ProseMirror {
    padding: 0 !important;
    min-height: auto !important;
  }
  /* Title text styling */
  h1.editable .toastui-editor .ProseMirror {
    font-size: 2.5rem;
    font-weight: 500;
    line-height: 1.2;
  }
  h2.editable .toastui-editor .ProseMirror {
    font-size: 2rem;
    font-weight: 500;
    line-height: 1.2;
  }
  .editable.title .toastui-editor .ProseMirror {
    font-size: 2.5rem;
    font-weight: 500;
    line-height: 1.2;
  }
  /* Auto-grow editors - no scrollbars */
  .edit-mode .toastui-editor-defaultUI,
  .edit-mode .toastui-editor-main,
  .edit-mode .toastui-editor-md-container,
  .edit-mode .toastui-editor-ww-container,
  .edit-mode .toastui-editor,
  .edit-mode .ProseMirror {
    height: auto !important;
    min-height: 100px !important;
    max-height: none !important;
    overflow: visible !important;
  }
  .edit-mode .toastui-editor-main {
    overflow: visible !important;
  }
  /* Write mode: show editor, hide preview, full width */
  .edit-mode .toastui-editor-md-splitter,
  .edit-mode .toastui-editor-md-preview {
    display: none !important;
  }
  .edit-mode .toastui-editor-md-container,
  .edit-mode .toastui-editor-md-container .toastui-editor-md-tab-container,
  .edit-mode .toastui-editor-md-container .toastui-editor {
    width: 100% !important;
    flex: 1 1 100% !important;
  }
  /* Preview mode: show preview, hide editor */
  .preview-mode .toastui-editor-md-container .toastui-editor-md-splitter,
  .preview-mode .toastui-editor-md-container .toastui-editor {
    display: none !important;
  }
  .preview-mode .toastui-editor-md-preview {
    display: block !important;
    width: 100% !important;
  }
`;
document.head.appendChild(style);

console.log('Toast UI Markdown editor loaded');
