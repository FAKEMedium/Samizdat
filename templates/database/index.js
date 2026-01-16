(async function () {
  const basePath = window.location.pathname.replace(/\/$/, '');

  // Filter elements
  const filterType = document.querySelector('#filterType');
  const searchtermInput = document.querySelector('#searchterm');

  // Type names map (populated from API)
  let typeNames = {};

  async function fetchTypes() {
    const data = await window.authenticatedFetch('<%== url_for("Database.types") %>');
    if (data && data.types) {
      // Populate dropdown and type names map
      filterType.innerHTML = `<option value=""><%== __('All types') %></option>`;
      for (const type of data.types) {
        typeNames[type.databasetypeid] = type.databasetypename;
        const opt = document.createElement('option');
        opt.value = type.databasetypeid;
        opt.textContent = type.databasetypename;
        filterType.appendChild(opt);
      }
    }
  }

  async function fetchDatabases() {
    const params = new URLSearchParams();

    const searchterm = searchtermInput?.value || '';
    if (searchterm) params.set('searchterm', searchterm);

    const typeid = filterType?.value || '';
    if (typeid) params.set('databasetypeid', typeid);

    const url = params.toString() ? `${basePath}?${params.toString()}` : basePath;
    const data = await window.authenticatedFetch(url);
    if (data) {
      populate(data);
    }
  }

  function populate(formdata) {
    let databases = formdata.databases || [];
    let snippet = '';

    databases = databases.sortBy('databasename');
    for (const db of databases) {
      const typeName = typeNames[db.databasetypeid] || db.databasetypeid;
      const usage = db.db_usage > 0 ? shortbytes(db.db_usage) : '-';

      snippet += `
        <tr data-databaseid="${db.databaseid}">
          <td><a href="<%== url_for('customer_index') %>/${db.customerid}/databases/${db.databasename}">${db.databasename}</a></td>
          <td>${typeName}</td>
          <td>${db.username || ''}</td>
          <td><a href="<%== url_for('customer_index') %>/${db.customerid}">${db.customerid}</a></td>
          <td class="text-end">${usage}</td>
        </tr>`;
    }
    document.querySelector('#databases tbody').innerHTML = snippet;

    // Update count
    document.querySelector('#pagination-info').textContent =
      databases.length > 0 ? `${databases.length} <%== __('databases') %>` : '';
  }

  // Event handlers
  document.querySelector('#dataform')?.addEventListener('submit', (e) => {
    e.preventDefault();
    fetchDatabases();
  });

  filterType?.addEventListener('change', () => fetchDatabases());

  // Initial load - fetch types first, then databases
  await fetchTypes();
  fetchDatabases();
})();
