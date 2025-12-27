const modalContent = document.querySelector('.modal-content');
const modalTitle = document.getElementById('modalTitle');
const modalBody = document.getElementById('modalBody');
const modalFooter = document.getElementById('modalFooter');

const isFallback = modalContent.dataset.isFallback === '1';
const targetLang = modalContent.dataset.targetLang;
const defaultLang = modalContent.dataset.defaultLang;
const hasAnthropic = modalContent.dataset.hasAnthropic === '1';
const translateUrl = modalContent.dataset.translateUrl;
const languagesUrl = modalContent.dataset.languagesUrl;

if (isFallback) {
  // Fallback/translation mode
  modalTitle.textContent = `No ${targetLang.toUpperCase()} translation found`;
  modalBody.innerHTML = `
    <p>This page doesn't have a ${targetLang.toUpperCase()} version yet. How would you like to proceed?</p>
    <div class="d-grid gap-2">
      <button type="button" class="btn btn-outline-secondary w-100 mb-2" id="fallbackEmpty">Start with empty content</button>
      <button type="button" class="btn btn-primary w-100 mb-2" id="fallbackCopy">Copy content from ${defaultLang.toUpperCase()} version</button>
      ${hasAnthropic ? `<button type="button" class="btn btn-success w-100 mb-2" id="fallbackTranslate" data-translate-url="${translateUrl}">Translate from ${defaultLang.toUpperCase()} to ${targetLang.toUpperCase()}</button>` : ''}
    </div>
  `;
} else {
  // New content mode
  modalTitle.textContent = 'Add new content';
  modalBody.innerHTML = `
    <form id="newContentForm">
      <div class="mb-3">
        <label for="newContentPath" class="form-label">Path (src directory)</label>
        <div class="input-group">
          <span class="input-group-text">src/public/</span>
          <input type="text" class="form-control" id="newContentPath" name="path" placeholder="project/my-page" required>
        </div>
        <div class="form-text">Directory path where the content will be created</div>
      </div>
      <div class="mb-3">
        <label class="form-label">Content type</label>
        <div class="form-check">
          <input class="form-check-input" type="radio" name="contentType" id="typeReadme" value="readme" checked>
          <label class="form-check-label" for="typeReadme"><strong>README</strong> - Main page content</label>
        </div>
        <div class="form-check">
          <input class="form-check-input" type="radio" name="contentType" id="typeSidecard" value="sidecard">
          <label class="form-check-label" for="typeSidecard"><strong>Sidecard</strong> - Sidebar content card</label>
        </div>
      </div>
      <div class="mb-3 d-none" id="sidecardNameGroup">
        <label for="sidecardName" class="form-label">Sidecard filename</label>
        <input type="text" class="form-control" id="sidecardName" name="sidecardName" placeholder="01_info">
        <div class="form-text">Name without extension (e.g., 01_info, 02_details)</div>
      </div>
      <div class="mb-3">
        <label for="newContentLang" class="form-label">Language</label>
        <select class="form-select" id="newContentLang" name="language">
          <option value="">Loading...</option>
        </select>
      </div>
    </form>
  `;
  modalFooter.innerHTML = `
    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
    <button type="button" class="btn btn-primary" id="createContentBtn">Create</button>
  `;

  // Fetch languages
  fetch(languagesUrl, { headers: { 'Accept': 'application/json' }, credentials: 'same-origin' })
    .then(r => r.json())
    .then(data => {
      const select = document.getElementById('newContentLang');
      select.innerHTML = data.languages.map(l =>
        `<option value="${l.code}"${l.code === defaultLang ? ' selected' : ''}>${l.name} (${l.code})</option>`
      ).join('');
    });

  // Toggle sidecard name field
  document.querySelectorAll('input[name="contentType"]').forEach(radio => {
    radio.addEventListener('change', () => {
      document.getElementById('sidecardNameGroup').classList.toggle('d-none', radio.value !== 'sidecard');
    });
  });

  // Handle create button
  document.getElementById('createContentBtn')?.addEventListener('click', () => {
    const form = document.getElementById('newContentForm');
    const path = document.getElementById('newContentPath').value.trim();
    const contentType = document.querySelector('input[name="contentType"]:checked').value;
    const language = document.getElementById('newContentLang').value;
    const sidecardName = document.getElementById('sidecardName')?.value.trim();

    if (!path) {
      alert('Please enter a path');
      return;
    }

    // Build the target URL
    let targetPath = '/' + path.replace(/^\/+/, '').replace(/\/+$/, '') + '/';

    // Navigate to the new page (it will show fallback content for editing)
    window.location.href = targetPath;
  });
}