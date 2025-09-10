let docid = document.documentElement.dataset.docid || 0;
let editor = 0;

// Editor Manager for multiple TipTap instances
class TipTapEditorManager {
  constructor() {
    this.editors = new Map();
    this.activeEditor = null;
    this.toolbar = null;
    this.offcanvas = null;
  }

  async init() {
    // Load the offcanvas toolbar
    await this.loadOffcanvasToolbar();
    this.bindGlobalEvents();
  }

  async loadOffcanvasToolbar() {
    try {
      const theContent = document.querySelector('#thecontent');
      const baseUrl = theContent?.dataset.toolbar || '/web/editor/toolbar/';
      const response = await fetch(baseUrl, {
        method: 'GET',
        headers: { 'Accept': 'text/html' }
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const offcanvasHTML = await response.text();
      const tempContainer = document.createElement('div');
      tempContainer.innerHTML = offcanvasHTML;
      
      // Add SVG symbols to document
      const svgElement = tempContainer.querySelector('svg[aria-hidden="true"]');
      if (svgElement) {
        const existingSvg = document.querySelector('svg[aria-hidden="true"]');
        if (existingSvg) {
          // Merge symbols into existing SVG
          const newDefs = svgElement.querySelector('defs');
          const existingDefs = existingSvg.querySelector('defs');
          if (newDefs && existingDefs) {
            Array.from(newDefs.children).forEach(symbol => {
              if (symbol.id && !existingDefs.querySelector(`#${symbol.id}`)) {
                existingDefs.appendChild(symbol);
              }
            });
          }
        } else {
          // Add the whole SVG
          document.body.insertBefore(svgElement, document.body.firstChild);
        }
      }
      
      // Add offcanvas to document
      const offcanvasElement = tempContainer.querySelector('.offcanvas');
      if (offcanvasElement) {
        document.body.appendChild(offcanvasElement);
        this.offcanvas = new bootstrap.Offcanvas(offcanvasElement, {
          backdrop: false, // Disable backdrop so it doesn't block editor
          keyboard: false  // Disable keyboard closing so editor can receive keyboard input
        });
        this.toolbar = offcanvasElement.querySelector('.offcanvas-body');
      }
    } catch (error) {
      console.error('Failed to load TipTap offcanvas toolbar:', error);
    }
  }

  bindGlobalEvents() {
    if (!this.toolbar) return;
    
    // Handle toolbar button clicks
    this.toolbar.addEventListener('click', (e) => {
      const button = e.target.closest('[data-action]');
      if (!button || !this.activeEditor) return;
      
      const action = button.dataset.action;
      this.handleAction(action, button);
    });

    // Handle heading dropdown
    this.toolbar.addEventListener('change', (e) => {
      if (e.target.dataset.action === 'heading' && this.activeEditor) {
        const level = e.target.value;
        if (level) {
          this.activeEditor.chain().focus().toggleHeading({ level: parseInt(level) }).run();
        } else {
          this.activeEditor.chain().focus().setParagraph().run();
        }
      }
    });
  }

  createEditor(element) {
    const editor = new Editor({
      element: element,
      extensions: [
        StarterKit.configure({
          link: false, // Disable the built-in link extension
        }),
        Link.configure({
          openOnClick: false,
          HTMLAttributes: {
            class: 'text-primary text-decoration-underline'
          }
        }),
        Image.configure({
          HTMLAttributes: {
            class: 'img-fluid'
          }
        }),
        Table.configure({
          resizable: true,
        }),
        TableRow,
        TableHeader,
        TableCell,
      ],
      onFocus: () => {
        console.log('TipTap editor received focus');
        this.setActiveEditor(editor);
        // Don't automatically show offcanvas - let edit button control it
      },
      onBlur: ({ event }) => {
        // Don't hide toolbar if clicking within it
        if (event?.relatedTarget?.closest('#tiptapToolbar')) {
          return;
        }
      }
    });

    this.editors.set(element, editor);
    return editor;
  }

  setActiveEditor(editor) {
    this.activeEditor = editor;
    this.updateToolbarState();
  }

  updateToolbarState() {
    // Update button states based on active editor
    if (!this.toolbar || !this.activeEditor) return;
    
    const editor = this.activeEditor;
    
    // Update button active states
    const buttons = {
      'bold': this.toolbar.querySelector('[data-action="bold"]'),
      'italic': this.toolbar.querySelector('[data-action="italic"]'),
      'underline': this.toolbar.querySelector('[data-action="underline"]'),
      'strike': this.toolbar.querySelector('[data-action="strike"]'),
      'bulletList': this.toolbar.querySelector('[data-action="bulletList"]'),
      'orderedList': this.toolbar.querySelector('[data-action="orderedList"]'),
      'blockquote': this.toolbar.querySelector('[data-action="blockquote"]'),
      'codeBlock': this.toolbar.querySelector('[data-action="codeBlock"]')
    };
    
    Object.entries(buttons).forEach(([action, button]) => {
      if (button) {
        button.classList.toggle('active', editor.isActive(action));
      }
    });
    
    // Update table button states
    const isInTable = editor.isActive('table');
    const tableButtons = [
      'addColumnBefore', 'addColumnAfter', 'deleteColumn',
      'addRowBefore', 'addRowAfter', 'deleteRow', 'deleteTable'
    ];
    
    tableButtons.forEach(action => {
      const button = this.toolbar.querySelector(`[data-action="${action}"]`);
      if (button) {
        button.disabled = !isInTable;
      }
    });

    // Update heading dropdown
    const headingSelect = this.toolbar.querySelector('[data-action="heading"]');
    if (headingSelect) {
      for (let i = 1; i <= 6; i++) {
        if (editor.isActive('heading', { level: i })) {
          headingSelect.value = i.toString();
          return;
        }
      }
      headingSelect.value = '';
    }
  }

  handleAction(action, button) {
    const editor = this.activeEditor;
    if (!editor) return;
    
    switch(action) {
      case 'bold':
        editor.chain().focus().toggleBold().run();
        break;
      case 'italic':
        editor.chain().focus().toggleItalic().run();
        break;
      case 'underline':
        editor.chain().focus().toggleUnderline().run();
        break;
      case 'strike':
        editor.chain().focus().toggleStrike().run();
        break;
      case 'bulletList':
        editor.chain().focus().toggleBulletList().run();
        break;
      case 'orderedList':
        editor.chain().focus().toggleOrderedList().run();
        break;
      case 'blockquote':
        editor.chain().focus().toggleBlockquote().run();
        break;
      case 'codeBlock':
        editor.chain().focus().toggleCodeBlock().run();
        break;
      case 'link':
        const url = prompt('Enter URL:');
        if (url) {
          editor.chain().focus().setLink({ href: url }).run();
        }
        break;
      case 'image':
        const src = prompt('Enter image URL:');
        if (src) {
          editor.chain().focus().setImage({ src }).run();
        }
        break;
      case 'insertTable':
        editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run();
        break;
      case 'addColumnBefore':
        editor.chain().focus().addColumnBefore().run();
        break;
      case 'addColumnAfter':
        editor.chain().focus().addColumnAfter().run();
        break;
      case 'deleteColumn':
        editor.chain().focus().deleteColumn().run();
        break;
      case 'addRowBefore':
        editor.chain().focus().addRowBefore().run();
        break;
      case 'addRowAfter':
        editor.chain().focus().addRowAfter().run();
        break;
      case 'deleteRow':
        editor.chain().focus().deleteRow().run();
        break;
      case 'deleteTable':
        editor.chain().focus().deleteTable().run();
        break;
      case 'save':
        this.saveActiveEditor();
        break;
      case 'cancel':
        this.cancelActiveEditor();
        break;
    }
  }

  saveActiveEditor() {
    // This will be handled by the global save button
    document.getElementById('savePageButton')?.click();
  }

  cancelActiveEditor() {
    // This will be handled by the global cancel button
    document.getElementById('cancelPageButton')?.click();
  }

  destroyEditor(element) {
    const editor = this.editors.get(element);
    if (editor) {
      editor.destroy();
      this.editors.delete(element);
      if (this.activeEditor === editor) {
        this.activeEditor = null;
      }
    }
  }

  getActiveEditor() {
    return this.activeEditor;
  }

  hideToolbar() {
    if (this.offcanvas) {
      this.offcanvas.hide();
    }
  }
}

import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import Image from '@tiptap/extension-image'
import { Table } from '@tiptap/extension-table'
import { TableRow } from '@tiptap/extension-table-row'
import { TableCell } from '@tiptap/extension-table-cell'
import { TableHeader } from '@tiptap/extension-table-header'

// Bootstrap-based TipTap toolbar
class BootstrapTipTapToolbar {
  constructor(editor, container) {
    this.editor = editor;
    this.container = container;
    this.init();
  }

  async init() {
    await this.createToolbar();
    this.bindEvents();
  }

  async createToolbar() {
    try {
      const theContent = document.querySelector('#thecontent');
      const toolbarUrl = theContent ? theContent.dataset.toolbar : '/web/editor/toolbar/';
      const response = await fetch(toolbarUrl, {
        method: 'GET',
        headers: { 'Accept': 'text/html' }
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const toolbarHTML = await response.text();
      const toolbarContainer = document.createElement('div');
      toolbarContainer.innerHTML = toolbarHTML;
      
      // Add SVG symbols to document
      const tiptapDefs = toolbarContainer.querySelector('#tiptapdefs');
      if (tiptapDefs) {
        const topDefs = document.querySelector('#topdefs');
        if (topDefs) {
          // Merge toolbar symbols into main page symbols (avoid duplicates)
          while (tiptapDefs.firstChild) {
            const symbol = tiptapDefs.firstChild;
            const symbolId = symbol.id;
            if (symbolId && !topDefs.querySelector(`#${symbolId}`)) {
              topDefs.appendChild(symbol);
            } else {
              tiptapDefs.removeChild(symbol);
            }
          }
        } else {
          // Fallback: add to document head
          const svgSymbols = toolbarContainer.querySelector('svg[aria-hidden="true"]');
          if (svgSymbols) {
            document.head.appendChild(svgSymbols);
          }
        }
      }
      
      // Find the toolbar div (skip the SVG symbols)
      const toolbar = toolbarContainer.querySelector('.btn-toolbar') || toolbarContainer.lastElementChild;
      
      this.container.insertBefore(toolbar, this.container.firstChild);
      this.toolbar = toolbar;
    } catch (error) {
      console.error('Failed to load TipTap toolbar:', error);
      // Fallback: create a basic toolbar
      const toolbar = document.createElement('div');
      toolbar.className = 'btn-toolbar mb-3 p-2 border-bottom bg-light';
      toolbar.innerHTML = '<div class="alert alert-warning">Toolbar failed to load</div>';
      this.container.insertBefore(toolbar, this.container.firstChild);
      this.toolbar = toolbar;
    }
  }

  bindEvents() {
    this.toolbar.addEventListener('click', (e) => {
      const button = e.target.closest('[data-action]');
      if (!button) return;
      
      const action = button.dataset.action;
      this.handleAction(action, button);
    });

    this.toolbar.addEventListener('change', (e) => {
      if (e.target.dataset.action === 'heading') {
        const level = e.target.value;
        if (level) {
          this.editor.chain().focus().toggleHeading({ level: parseInt(level) }).run();
        } else {
          this.editor.chain().focus().setParagraph().run();
        }
      }
    });

    // Update button states on selection change
    this.editor.on('selectionUpdate', () => {
      this.updateButtonStates();
    });
  }

  handleAction(action, button) {
    const editor = this.editor;
    
    switch(action) {
      case 'bold':
        editor.chain().focus().toggleBold().run();
        break;
      case 'italic':
        editor.chain().focus().toggleItalic().run();
        break;
      case 'underline':
        editor.chain().focus().toggleUnderline().run();
        break;
      case 'strike':
        editor.chain().focus().toggleStrike().run();
        break;
      case 'bulletList':
        editor.chain().focus().toggleBulletList().run();
        break;
      case 'orderedList':
        editor.chain().focus().toggleOrderedList().run();
        break;
      case 'blockquote':
        editor.chain().focus().toggleBlockquote().run();
        break;
      case 'codeBlock':
        editor.chain().focus().toggleCodeBlock().run();
        break;
      case 'link':
        const url = prompt('Enter URL:');
        if (url) {
          editor.chain().focus().setLink({ href: url }).run();
        }
        break;
      case 'image':
        const src = prompt('Enter image URL:');
        if (src) {
          editor.chain().focus().setImage({ src }).run();
        }
        break;
      case 'insertTable':
        editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run();
        break;
      case 'addColumnBefore':
        editor.chain().focus().addColumnBefore().run();
        break;
      case 'addColumnAfter':
        editor.chain().focus().addColumnAfter().run();
        break;
      case 'deleteColumn':
        editor.chain().focus().deleteColumn().run();
        break;
      case 'addRowBefore':
        editor.chain().focus().addRowBefore().run();
        break;
      case 'addRowAfter':
        editor.chain().focus().addRowAfter().run();
        break;
      case 'deleteRow':
        editor.chain().focus().deleteRow().run();
        break;
      case 'deleteTable':
        editor.chain().focus().deleteTable().run();
        break;
      case 'save':
        this.onSave && this.onSave(editor.getHTML());
        break;
      case 'cancel':
        this.onCancel && this.onCancel();
        break;
    }
  }

  updateButtonStates() {
    if (!this.toolbar) return;
    
    const editor = this.editor;
    
    // Update button active states
    const boldBtn = this.toolbar.querySelector('[data-action="bold"]');
    const italicBtn = this.toolbar.querySelector('[data-action="italic"]');
    const underlineBtn = this.toolbar.querySelector('[data-action="underline"]');
    const strikeBtn = this.toolbar.querySelector('[data-action="strike"]');
    const bulletListBtn = this.toolbar.querySelector('[data-action="bulletList"]');
    const orderedListBtn = this.toolbar.querySelector('[data-action="orderedList"]');
    const blockquoteBtn = this.toolbar.querySelector('[data-action="blockquote"]');
    const codeBlockBtn = this.toolbar.querySelector('[data-action="codeBlock"]');
    
    if (boldBtn) boldBtn.classList.toggle('active', editor.isActive('bold'));
    if (italicBtn) italicBtn.classList.toggle('active', editor.isActive('italic'));
    if (underlineBtn) underlineBtn.classList.toggle('active', editor.isActive('underline'));
    if (strikeBtn) strikeBtn.classList.toggle('active', editor.isActive('strike'));
    if (bulletListBtn) bulletListBtn.classList.toggle('active', editor.isActive('bulletList'));
    if (orderedListBtn) orderedListBtn.classList.toggle('active', editor.isActive('orderedList'));
    if (blockquoteBtn) blockquoteBtn.classList.toggle('active', editor.isActive('blockquote'));
    if (codeBlockBtn) codeBlockBtn.classList.toggle('active', editor.isActive('codeBlock'));
    
    // Update table button states
    const isInTable = editor.isActive('table');
    const addColumnBeforeBtn = this.toolbar.querySelector('[data-action="addColumnBefore"]');
    const addColumnAfterBtn = this.toolbar.querySelector('[data-action="addColumnAfter"]');
    const deleteColumnBtn = this.toolbar.querySelector('[data-action="deleteColumn"]');
    const addRowBeforeBtn = this.toolbar.querySelector('[data-action="addRowBefore"]');
    const addRowAfterBtn = this.toolbar.querySelector('[data-action="addRowAfter"]');
    const deleteRowBtn = this.toolbar.querySelector('[data-action="deleteRow"]');
    const deleteTableBtn = this.toolbar.querySelector('[data-action="deleteTable"]');
    
    if (addColumnBeforeBtn) addColumnBeforeBtn.disabled = !isInTable;
    if (addColumnAfterBtn) addColumnAfterBtn.disabled = !isInTable;
    if (deleteColumnBtn) deleteColumnBtn.disabled = !isInTable;
    if (addRowBeforeBtn) addRowBeforeBtn.disabled = !isInTable;
    if (addRowAfterBtn) addRowAfterBtn.disabled = !isInTable;
    if (deleteRowBtn) deleteRowBtn.disabled = !isInTable;
    if (deleteTableBtn) deleteTableBtn.disabled = !isInTable;

    // Update heading dropdown
    const headingSelect = this.toolbar.querySelector('[data-action="heading"]');
    if (headingSelect) {
      for (let i = 1; i <= 6; i++) {
        if (editor.isActive('heading', { level: i })) {
          headingSelect.value = i.toString();
          return;
        }
      }
      headingSelect.value = '';
    }
  }
}

// Simple editor creation function for contenteditable elements
window.createSimpleEditor = function(content, index) {
    // Store original content for cancel
    const originalHTML = content.innerHTML;
    content.dataset.originalContent = originalHTML;
    
    // Simple editor object for compatibility
    const editor = {
        element: content,
        index: index,
        getHTML: () => content.innerHTML,
        setContent: (html) => content.innerHTML = html,
        setEditable: (editable) => {
            content.contentEditable = editable;
            if (editable) {
                // Convert picture elements to simple img tags for editing
                editor.convertPicturesToImg(content);
                
                // Set up text-only mode for heading elements
                if (content.tagName && content.tagName.match(/^H[1-6]$/i)) {
                    editor.setupTextOnlyMode(content);
                }
                
                content.style.border = '2px solid #007bff';
                content.style.padding = '10px';
                content.style.cursor = 'text';
            } else {
                content.style.border = '';
                content.style.padding = '';
                content.style.cursor = '';
            }
        },
        convertPicturesToImg: (container) => {
            const pictures = container.querySelectorAll('picture');
            pictures.forEach(picture => {
                const img = picture.querySelector('img');
                if (img) {
                    // Clone the img and insert it before the picture element
                    const newImg = img.cloneNode(true);
                    picture.parentNode.insertBefore(newImg, picture);
                    // Remove the picture element
                    picture.remove();
                }
            });
        },
        setupTextOnlyMode: (element) => {
            // Strip any existing HTML and keep only text content
            element.textContent = element.textContent;
            
            // Prevent paste of formatted content
            element.addEventListener('paste', (e) => {
                e.preventDefault();
                const text = (e.clipboardData || window.clipboardData).getData('text/plain');
                document.execCommand('insertText', false, text);
            });
            
            // Prevent drag/drop of formatted content
            element.addEventListener('drop', (e) => {
                e.preventDefault();
                const text = e.dataTransfer.getData('text/plain');
                if (text) {
                    document.execCommand('insertText', false, text);
                }
            });
            
            // Block formatting keyboard shortcuts
            element.addEventListener('keydown', (e) => {
                // Block Ctrl+B, Ctrl+I, Ctrl+U, etc.
                if (e.ctrlKey || e.metaKey) {
                    const blockedKeys = ['b', 'i', 'u', 'k']; // bold, italic, underline, link
                    if (blockedKeys.includes(e.key.toLowerCase())) {
                        e.preventDefault();
                    }
                }
                
                // Block Enter key to prevent new lines in headings
                if (e.key === 'Enter') {
                    e.preventDefault();
                }
            });
            
            // Clean up any HTML that might get inserted
            element.addEventListener('input', (e) => {
                // If innerHTML differs from textContent, clean it up
                const textOnly = element.textContent;
                if (element.innerHTML !== textOnly) {
                    const selection = window.getSelection();
                    const range = selection.getRangeAt(0);
                    const startOffset = range.startOffset;
                    
                    element.textContent = textOnly;
                    
                    // Restore cursor position
                    if (element.firstChild) {
                        range.setStart(element.firstChild, Math.min(startOffset, textOnly.length));
                        range.collapse(true);
                        selection.removeAllRanges();
                        selection.addRange(range);
                    }
                }
            });
        },
        destroy: () => {
            content.contentEditable = 'false';
            content.style.border = '';
            content.style.padding = '';
            content.style.cursor = '';
        }
    };
    
    // Add click handler to focus this editor and set as current
    content.addEventListener('click', () => {
        if (content.contentEditable === 'true') {
            window.currentEditor = editor;
            console.log(`Switched to editor for element ${index}`);
        }
    });
    
    return editor;
};

// Initialize simple editors for all .editable elements
window.initSimpleEditors = function() {
    console.log('Starting simple editor initialization...');
    
    try {
        const theContent = document.getElementById('thecontent');
        if (!theContent) {
            console.error('thecontent element not found');
            return null;
        }
        
        // Check if #thecontent is editable - if not, don't initialize any editors
        if (!theContent.classList.contains('editable')) {
            console.log('#thecontent is not editable, skipping editor initialization');
            return null;
        }
        
        // #thecontent is editable, so find all .editable elements to make them editable too
        const editableElements = document.querySelectorAll('.editable');
        console.log(`#thecontent is editable, found ${editableElements.length} total .editable elements:`, editableElements);
        
        const editors = [];
        
        // Create editor objects for each editable element
        editableElements.forEach((content, index) => {
            const editor = window.createSimpleEditor(content, index);
            editors.push(editor);
        });
        
        console.log(`${editors.length} simple contenteditable editors initialized`);
        
        // Set up global editor reference (first one by default)
        window.currentEditor = editors[0];
        window.allEditors = editors;
        
        return editors;
    } catch (error) {
        console.error('Error in initSimpleEditors:', error);
        return null;
    }
};

// Global editor manager instance
window.tiptapManager = null;

// Initialize the editor manager
window.initTipTapManager = async function() {
  if (!window.tiptapManager) {
    window.tiptapManager = new TipTapEditorManager();
    await window.tiptapManager.init();
  }
  return window.tiptapManager;
};

// Create editor for a specific element
window.createEditor = async function(element, content) {
  const manager = await window.initTipTapManager();
  const editor = manager.createEditor(element);
  if (content) {
    editor.commands.setContent(content);
  }
  return editor;
};

// Export TipTap globally for dynamic loading
window.TipTap = {
  Editor,
  StarterKit,
  Link,
  Image,
  Table,
  TableRow,
  TableCell,
  TableHeader,
  BootstrapTipTapToolbar,
  TipTapEditorManager
};