document.querySelector('#loginform').addEventListener("submit", (event) => {event.preventDefault()});

async function login () {
    const loginform = document.querySelector('#loginform');
    const loginalert = document.querySelector('#loginalert');
    const loginbody = document.querySelector('#loginbody');
    const modaltitle = document.querySelector('#modaltitle');
    try {
        const formdata = new FormData(loginform);
        const response = await fetch('<%= url_for("account_login") %>', {
            method: 'POST',
            mode: "cors",
            cache: "no-cache",
            credentials: "same-origin",
            headers: {
                Accept: 'application/json'
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
        if (jsonData.userdata) {
            window.location.reload(true);
        } else if (jsonData.error) {
            if ('blocked' == jsonData.error.reason) {
                modaltitle.innerHTML = `<%== __("Login blocked") %>`;
                let message = `
    <div class="alert alert-danger">
      <%== __x('Login is temporarily blocked due to excessive failed attempts from {ip}.', ip => 'remote_host') %>
      <%== __x('The limit is {blocklimit} attempts per {blocktime} minutes.',
        blocklimit => 'blocklimit',
        blocktime => 'blocktime') %>
    </div>
`
                .replace('remote_host', jsonData.ip)
                .replace('blocklimit', jsonData.blocklimit)
                .replace('blocktime', jsonData.blocktime);
                loginbody.innerHTML = message;
            } else if ('password' == jsonData.error.reason) {
                let message = `
    <%== __("Password was wrong or username doesn't exist.") %>
    <%== __x('You have {remaining} tries left.', remaining => 'remaining') %>
    `.replace('remaining', jsonData.blocklimit - jsonData.error.count);
                loginalert.classList.add('alert-danger');
                loginalert.classList.remove('alert-light');
                loginalert.innerHTML = message;
            } else if ('incomplete' == jsonData.error.reason) {
                loginalert.classList.add('alert-danger');
                loginalert.innerHTML = '<%== __("Missing username or password") %>';
            }
        } else if (jsonData.error) {
            loginform.innerHTML = jsonData.error;
        }
    } catch (error) {
        // console.error('Login error:', error);
        loginalert.classList.add('alert-danger');
        loginalert.innerHTML = '<%== __("An error occurred during login. Please try again.") %>';
    }
}