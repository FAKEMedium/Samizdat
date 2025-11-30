(async function () {
  const universalModal = new bootstrap.Modal('#universalmodal');
  const modalDialog = document.querySelector('#universalmodal #modalDialog');

  async function loadMenus() {
    const data = await window.authenticatedFetch(window.location.href);
    if (data) {
      populate(data);
    }
  }

  async function openNewMenuModal() {
    modalDialog.innerHTML = `
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title"><%== __('New Menu') %></h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
        </div>
        <div class="modal-body">
          <form id="newMenuForm">
            <div class="mb-3">
              <label for="menuName" class="form-label"><%== __('Name') %></label>
              <input type="text" class="form-control" id="menuName" name="name" required>
            </div>
          </form>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><%== __('Cancel') %></button>
          <button type="button" class="btn btn-primary" id="saveNewMenu"><%== __('Create') %></button>
        </div>
      </div>
    `;
    universalModal.show();

    document.querySelector('#saveNewMenu').addEventListener('click', async () => {
      const name = document.querySelector('#menuName').value;
      if (!name) return;

      const result = await window.authenticatedFetch(window.location.href, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
      });

      if (result && result.success) {
        universalModal.hide();
        window.showToast('<%== __("Menu created") %>');
        loadMenus();
      }
    });
  }

  document.querySelector('#newMenu')?.addEventListener('click', openNewMenuModal);

  // Search filter
  document.querySelector('#dataform')?.addEventListener('submit', (e) => {
    e.preventDefault();
    const searchterm = document.querySelector('#searchterm').value.toLowerCase();
    document.querySelectorAll('#menus tbody tr').forEach(row => {
      const name = row.querySelector('td:nth-child(2)')?.textContent.toLowerCase() || '';
      row.style.display = name.includes(searchterm) ? '' : 'none';
    });
  });

  function populate(data) {
    const menus = data.menus || [];
    let snippet = '';
    menus.forEach(menu => {
      snippet += `
      <tr data-menuid="${menu.menuid}">
        <td class="px-2">${menu.menuid}</td>
        <td class="px-2">${menu.name}</td>
        <td class="text-end px-2">
          <a href="<%== url_for('web_menus') %>/${menu.menuid}" class="btn btn-sm btn-secondary">
            <%== icon 'pencil-fill', {} %> <%== __('Edit') %>
          </a>
          <button data-menuid="${menu.menuid}" class="btn btn-sm btn-danger btn-delete">
            <%== icon 'trash-fill', {} %> <%== __('Delete') %>
          </button>
        </td>
      </tr>
      `;
    });
    document.querySelector('#menus tbody').innerHTML = snippet || '<tr><td colspan="3" class="text-center"><%== __("No menus found") %></td></tr>';

    // Delete button handlers
    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (!confirm('<%== __("Are you sure you want to delete this menu?") %>')) return;
        const menuid = btn.getAttribute('data-menuid');
        const result = await window.authenticatedFetch(`<%== url_for('web_menus') %>/${menuid}`, {
          method: 'DELETE'
        });
        if (result && result.success) {
          btn.closest('tr').remove();
          window.showToast('<%== __("Menu deleted") %>');
        }
      });
    });
  }

  loadMenus();
})();
