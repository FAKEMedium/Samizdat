fetch(location.pathname, { headers: { 'Accept': 'application/json' } })
  .then(r => r.json())
  .then(data => {
    if (data.services) {
      document.getElementById('noservices').classList.add('d-none');
      data.services.forEach(service => {
        const card = document.getElementById('cardcol-' + service);
        if (card) card.classList.remove('d-none');
      });
    }
  });
