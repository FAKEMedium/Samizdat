const userServices = ['customer', 'invoice', 'domain', 'zone', 'database', 'email'];
const u = window.username ?? '';
const sa = window.superadmin ?? 0;
const adm = window.admin ?? 0;

if (u) {
  document.getElementById('noservices').classList.add('d-none');
  document.querySelectorAll('.cardcol').forEach(card => {
    const service = card.id.replace('cardcol-', '');
    if (sa || adm || userServices.includes(service)) {
      card.classList.remove('d-none');
    }
  });
  if (sa || adm) {
    document.querySelectorAll('.cardcol .admin').forEach(el => el.classList.remove('admin'));
  }
}