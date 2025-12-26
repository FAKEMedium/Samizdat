// Toast UI Editor with GFM Markdown support
// Markdown-only editing of complete documents

console.log('Toast UI Editor module loading...');

import '@toast-ui/editor/dist/toastui-editor.css';
import { Editor } from '@toast-ui/editor';

console.log('Toast UI imports loaded successfully');

/**
 * Toast UI Markdown Editor Manager
 * Edit complete markdown documents (title + content together)
 */
class ToastUIMarkdownManager {
  constructor() {
    this.editors = new Map();
    this.originalContent = new Map();
    this.sourceData = null;
    this.isEditMode = false;
  }

  async fetchSourceContent() {
    const currentPath = window.location.pathname;
    const theContent = document.getElementById('thecontent');
    const baseSourceUrl = theContent?.dataset.source;

    if (!baseSourceUrl) {
      console.warn('ToastUI: No data-source attribute found on #thecontent');
      return null;
    }

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

  async enterEditMode() {
    if (this.isEditMode) return;

    this.sourceData = await this.fetchSourceContent();

    // Hide headline and headlinenav, show frontmatter editor
    const headline = document.getElementById('headline');
    const headlinenav = document.getElementById('headlinenav');
    if (headline) headline.style.display = 'none';
    if (headlinenav) headlinenav.style.display = 'none';

    // Create frontmatter editor in header area
    if (headline?.parentElement && this.sourceData?.main?.frontmatter) {
      const fmEditor = document.createElement('div');
      fmEditor.id = 'frontmatter-editor';
      fmEditor.className = 'col-12';
      fmEditor.innerHTML = `
        <details class="mb-2">
          <summary class="text-muted small">Frontmatter (YAML)</summary>
          <textarea id="frontmatter-textarea" class="form-control font-monospace" rows="4">${this.sourceData.main.frontmatter}</textarea>
        </details>
      `;
      headline.parentElement.appendChild(fmEditor);
    }

    // Create editor for main content (#thecontent)
    const mainContent = document.getElementById('thecontent');
    if (mainContent) {
      this.createEditor(mainContent, 'main');
    }

    // Create editors for sidecards
    const sidecards = document.querySelectorAll('.card.editable[data-src]');
    sidecards.forEach((card, index) => {
      this.createEditor(card, `sidecard-${index}`);
    });

    this.isEditMode = true;
    document.body.classList.add('edit-mode');
  }

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
        editor.destroy();
        // Content saved to server, page will reload
      }
    });

    // Restore headline and headlinenav
    const headline = document.getElementById('headline');
    const headlinenav = document.getElementById('headlinenav');
    if (headline) headline.style.display = '';
    if (headlinenav) headlinenav.style.display = '';

    // Remove frontmatter editor
    const fmEditor = document.getElementById('frontmatter-editor');
    if (fmEditor) fmEditor.remove();

    this.editors.clear();
    this.originalContent.clear();
    this.sourceData = null;
    this.isEditMode = false;
    document.body.classList.remove('edit-mode');
  }

  createEditor(element, editorId) {
    // Store original content for cancel
    this.originalContent.set(element, element.innerHTML);

    const isSidecard = element.classList.contains('card');
    const isMain = element.id === 'thecontent';

    // Get full markdown from source data
    let markdown = '';

    if (isMain && this.sourceData?.main?.markdown) {
      markdown = this.sourceData.main.markdown;
    } else if (isSidecard && this.sourceData?.sidecards) {
      const dataSrc = element.dataset.src;
      for (const card of this.sourceData.sidecards) {
        if (card.src === dataSrc) {
          markdown = card.markdown || '';
          break;
        }
      }
    }

    if (!markdown) {
      console.log(`ToastUI: No markdown source for ${editorId}`);
    }

    // Clear element and create editor container
    element.innerHTML = '';
    const editorContainer = document.createElement('div');
    element.appendChild(editorContainer);

    const editorConfig = {
      el: editorContainer,
      height: 'auto',
      minHeight: isSidecard ? '200px' : '400px',
      initialEditType: 'markdown',
      previewStyle: 'tab',
      initialValue: markdown,
      usageStatistics: false,
      hideModeSwitch: true,
      hooks: {
        addImageBlobHook: async (blob, callback) => {
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

    const editor = new Editor(editorConfig);
    this.editors.set(element, editor);

    console.log(`ToastUI: Editor created for ${editorId}`);
    return editor;
  }

  getContent() {
    const content = {};

    // Get frontmatter if edited
    const fmTextarea = document.getElementById('frontmatter-textarea');
    if (fmTextarea) {
      content['frontmatter'] = fmTextarea.value;
    }

    this.editors.forEach((editor, element) => {
      const isSidecard = element.classList.contains('card');
      const isMain = element.id === 'thecontent';

      if (isMain) {
        content['thecontent'] = editor.getMarkdown();
      } else if (isSidecard && element.dataset.src) {
        const srcBase = element.dataset.src.replace(/\.md$/, '');
        content[`${srcBase}-content`] = editor.getMarkdown();
      }
    });

    return content;
  }

  getEditorContent(element) {
    const editor = this.editors.get(element);
    if (!editor) return null;
    return editor.getMarkdown();
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
  .edit-mode #thecontent,
  .edit-mode .card.editable {
    border: 2px dashed #007bff;
    padding: 0.5rem;
  }
  /* Hide mode switch */
  .toastui-editor-mode-switch {
    display: none !important;
  }
  /* Auto-grow editors */
  .edit-mode .toastui-editor-defaultUI,
  .edit-mode .toastui-editor-main,
  .edit-mode .toastui-editor-md-container,
  .edit-mode .toastui-editor,
  .edit-mode .ProseMirror {
    height: auto !important;
    min-height: 150px !important;
    max-height: none !important;
    overflow: visible !important;
  }
  /* Hide splitter for tab mode (not side-by-side) */
  .edit-mode .toastui-editor-md-splitter {
    display: none !important;
  }
`;
document.head.appendChild(style);

console.log('Toast UI Markdown editor loaded');
