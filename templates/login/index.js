const loginform = document.getElementById('loginform')
loginform.addEventListener('submit',  (event) => {
    event.preventDefault()
    const url = loginform.action
    const method = loginform.method
    const submitbutton = document.getElementById("submitlogin");
    const response = submitform(url, method, loginform, submitbutton);
    if (1 === response.success)
        if ('/' === window.location.pathname)
            location.assign("/panel/")
        else
            window.location.reload(true)
    else
        if (2 === response.step)
            loginform.innerHTML = response.error
        else
            document.getElementById('loginalert').classList.add('alert-danger').innerHTML = response.error
})

async function submitform (url, method, form, submitter) {
    try {
        const formdata = FormData(form, submitter);
        const response = await fetch(url, {
            method: method,
            mode: "cors",
            cache: "no-cache",
            credentials: "same-origin",
            headers: {
                // "Content-Type": "application/json",
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            redirect: "follow",
            referrerPolicy: "no-referrer",
            body: formdata
        });
        const contentType = response.headers.get("content-type");
        if (!contentType || !contentType.includes("application/json")) {
            throw new TypeError("Oops, we haven't got JSON!");
        }
        const jsonData = await response.json();
    } catch (error) {
        console.error("Error:", error);
    }
}