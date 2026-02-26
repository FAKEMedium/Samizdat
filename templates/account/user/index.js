const uuid = window.location.pathname.split('/').filter(Boolean).pop();
const apiUrl = `<%= url_for('Account.presentation', uuid => '__UUID__') %>`.replace('__UUID__', uuid);

async function loadUser() {
  try {
    const response = await fetch(apiUrl, {
      headers: { Accept: 'application/json' }
    });
    const data = await response.json();

    document.getElementById('loadingSpinner').classList.add('d-none');

    if (!data.success) {
      document.getElementById('userNotFound').classList.remove('d-none');
      return;
    }

    const user = data.user;
    const presentation = data.presentation;
    const image = data.image;

    document.getElementById('userDisplayName').textContent = user.displayname || user.username;

    if (user.organization) {
      document.getElementById('userOrganization').textContent = user.organization;
    }

    if (image && image.filename) {
      const img = document.getElementById('userImage');
      img.src = `/user/${image.filename}`;
      img.alt = user.displayname || user.username;
      img.classList.remove('d-none');
    }

    if (user.city || user.country_cc) {
      const locationRow = document.getElementById('userLocationRow');
      locationRow.classList.remove('d-none');
      document.getElementById('userCity').textContent = user.city || '';
      if (user.country_cc) {
        const flagEl = document.getElementById('userCountryFlag');
        flagEl.innerHTML = ` <img src="/assets/flags/${user.country_cc.toLowerCase()}" width="24" height="18" alt="${user.country_cc}" />`;
      }
    }

    if (user.website) {
      const websiteRow = document.getElementById('userWebsiteRow');
      websiteRow.classList.remove('d-none');
      const link = document.getElementById('userWebsite');
      link.href = user.website;
      link.textContent = user.website.replace(/^https?:\/\//, '');
    }

    if (user.created) {
      document.getElementById('userMemberSince').textContent =
        '<%= __('Member since') %> ' + new Date(user.created).toLocaleDateString();
    }

    if (presentation && presentation.presentation) {
      document.getElementById('userPresentationText').textContent = presentation.presentation;
    }

    document.getElementById('userCard').classList.remove('d-none');
  } catch (e) {
    document.getElementById('loadingSpinner').classList.add('d-none');
    document.getElementById('userNotFound').classList.remove('d-none');
  }
}

loadUser();
