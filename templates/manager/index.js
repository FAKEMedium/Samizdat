const userServices = ['customer', 'invoice', 'domain', 'zone', 'database', 'email'];

if (username) {
  document.getElementById('noservices').classList.add('d-none');
  document.querySelectorAll('.cardcol').forEach(card => {
    const service = card.id.replace('cardcol-', '');
    if (superadmin || admin || userServices.includes(service)) {
      card.classList.remove('d-none');
    }
  });
  if (superadmin || admin) {
    document.querySelectorAll('.cardcol .admin').forEach(el => el.classList.remove('admin'));
  }
}
