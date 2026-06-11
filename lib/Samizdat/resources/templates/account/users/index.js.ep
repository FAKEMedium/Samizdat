let currentPage = 1;
let isAdmin = false;

async function loadUsers(page = 1) {
  currentPage = page;
  const result = await window.authenticatedFetch(`<%= url_for('Account.users.index') %>?page=${page}`, {
    method: 'GET'
  });

  if (result && result.success) {
    isAdmin = !!result.admin;
    const users = result.users || [];
    const total = result.total || 0;
    const limit = result.limit || 25;
    const totalPages = Math.ceil(total / limit);
    const colCount = isAdmin ? 5 : 4;

    if (isAdmin) {
      document.getElementById('statusHeader').classList.remove('d-none');
      document.getElementById('addUserBtn').classList.remove('d-none');
    }

    const tbody = document.querySelector('#users tbody');
    let html = '';

    users.forEach(user => {
      const created = user.created ? new Date(user.created).toLocaleDateString() : '';
      const flag = user.country_cc
        ? `<img src="/assets/flags/${user.country_cc.toLowerCase()}" width="24" height="18" alt="${user.country_cc}" />`
        : '';

      html += `<tr>
          <td><a href="/users/${user.useruuid}">${user.username}</a></td>
          <td>${user.displayname || ''}</td>
          <td>${flag}</td>
          <td>${created}</td>`;

      if (isAdmin) {
        const status = user.blocked ? '<span class="badge bg-danger"><%= __("Blocked") %></span>' :
                       user.activated ? '<span class="badge bg-success"><%= __("Active") %></span>' :
                       '<span class="badge bg-warning"><%= __("Inactive") %></span>';
        html += `<td>${status}</td>`;
      }

      html += `</tr>`;
    });

    tbody.innerHTML = html || `<tr><td colspan="${colCount}" class="text-muted text-center"><%= __("No users found") %></td></tr>`;

    buildPagination(page, totalPages);
  }
}

function buildPagination(page, totalPages) {
  const pagination = document.querySelector('#userPagination');
  let html = '';

  // Previous
  html += `<li class="page-item ${page <= 1 ? 'disabled' : ''}">
    <a class="page-link" href="#" data-page="${page - 1}">&laquo;</a>
  </li>`;

  // Pages
  const startPage = Math.max(1, page - 2);
  const endPage = Math.min(totalPages, page + 2);

  if (startPage > 1) {
    html += `<li class="page-item"><a class="page-link" href="#" data-page="1">1</a></li>`;
    if (startPage > 2) {
      html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
    }
  }

  for (let i = startPage; i <= endPage; i++) {
    html += `<li class="page-item ${i === page ? 'active' : ''}">
      <a class="page-link" href="#" data-page="${i}">${i}</a>
    </li>`;
  }

  if (endPage < totalPages) {
    if (endPage < totalPages - 1) {
      html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
    }
    html += `<li class="page-item"><a class="page-link" href="#" data-page="${totalPages}">${totalPages}</a></li>`;
  }

  // Next
  html += `<li class="page-item ${page >= totalPages ? 'disabled' : ''}">
    <a class="page-link" href="#" data-page="${page + 1}">&raquo;</a>
  </li>`;

  pagination.innerHTML = html;

  // Click handlers
  pagination.querySelectorAll('a.page-link').forEach(link => {
    link.addEventListener('click', (e) => {
      e.preventDefault();
      const targetPage = parseInt(link.dataset.page);
      if (targetPage >= 1 && targetPage <= totalPages && targetPage !== page) {
        loadUsers(targetPage);
      }
    });
  });
}

loadUsers();
