let docid = document.documentElement.dataset.docid || 0;
let editor = 0;

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
      const toolbarUrl = theContent ? theContent.dataset.toolbar : '/web/editor-toolbar/';
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
          // Merge toolbar symbols into main page symbols
          while (tiptapDefs.firstChild) {
            topDefs.appendChild(tiptapDefs.firstChild);
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
  BootstrapTipTapToolbar
};