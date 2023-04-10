const loginform = document.getElementById('loginform')
loginform.addEventListener('submit', (event) => {
    event.preventDefault()
    const url = self.attr('href') || self.attr('action')
    const method = this.data('method')
    response = await fetch(url, { method: method});

    if (1 === response.success)
        if ('/' === window.location.pathname)
            location.assign("/panel/")
        else
            window.location.reload(true)
    else
        if (2 === response.step)
            this.innerHTML = response.error
        else
            $document.getElementById('loginalert').classList.add('alert-danger').innerHTML = response.error
})