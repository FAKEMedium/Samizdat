// Toast UI Editor with GFM Markdown support
// Entry point for markdown-based editing

console.log('Toast UI Editor module loading...');

import '@toast-ui/editor/dist/toastui-editor.css';
import { Editor } from '@toast-ui/editor';

console.log('Toast UI imports loaded successfully');

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

    if (elementId === 'thecontent' || elementId === 'maincontent') {
      return this.sourceData.main?.content || null;
    }

    if (elementId === 'headline' || elementId === 'thetitle' || elementId === 'maintitle') {
      return this.sourceData.main?.title || null;
    }

    if (this.sourceData.sidecards && element) {
      const cardContainer = element.closest('[data-src]');
      if (cardContainer) {
        const dataSrc = cardContainer.dataset.src;
        for (const card of this.sourceData.sidecards) {
          if (card.src === dataSrc) {
            if (elementId.endsWith('-title')) {
              return card.title || '';
            } else {
              return card.content || '';
            }
          }
        }
      }
    }

    return null;
  }

  /**
   * Create a Toast UI editor for an element
   */
  createEditor(element, index) {
    this.originalContent.set(element, element.innerHTML);

    const elementId = element.id || `element-${index}`;
    const isTitle = element.classList.contains('title') ||
                    element.tagName.match(/^H[1-6]$/i);

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
      height: isTitle ? '100px' : '400px',
      initialEditType: 'markdown',
      previewStyle: 'tab',
      toolbarItems: [],  // No toolbar in editor, use headlinenav toggler instead
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

    // Smaller height for titles
    if (isTitle) {
      editorConfig.height = '80px';
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
      const elementId = element.id || element.dataset.toastuiIndex;
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
   * Set preview mode for all editors (markdown mode only)
   * @param {boolean} showPreview - true to show preview, false to show editor
   */
  setPreviewMode(showPreview) {
    this.editors.forEach((editor) => {
      if (showPreview) {
        editor.changePreviewStyle('tab');
        // Switch to preview tab
        const container = editor.getEditorElements().mdEditor.parentElement;
        const previewTab = container?.querySelector('.toastui-editor-tabs .tab-item:last-child');
        previewTab?.click();
      } else {
        // Switch to write tab
        const container = editor.getEditorElements().mdEditor.parentElement;
        const writeTab = container?.querySelector('.toastui-editor-tabs .tab-item:first-child');
        writeTab?.click();
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
  /* Hide built-in mode switch and tabs in editors - controlled from headlinenav */
  .toastui-editor-mode-switch,
  .toastui-editor-tabs {
    display: none !important;
  }
`;
document.head.appendChild(style);

console.log('Toast UI Markdown editor loaded');
