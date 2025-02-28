# AAA

Denna fil hjälper Webpack.
<script>
const myModal = new bootstrap.Modal('#universalmodal');
myModal.show();
</script>
<div class="row row-cols-1 row-cols-md-3 g-4 g-0 gap-0 row-gap-3">
  <div class="col-md-5 alert alert-light">
    <div class="card h-100 alert-danger">
      <h5 class="card-header orange border-0">u</h5>
      <div class="card-body m-0 p-2 input-group gx-0 gy-2 gap-2 mb-1 gx-2">
        <a class="d-md-inline badge rounded-pill text-bg-primary" href="/fortnox/work">y</a>
        <form name="searchcustomer" method="post" action="customer/">
          <input type="hidden" name="what" value="customer" />
          <div class="form-group row">
            <div class="custom-control custom-control-inline col-xl-5 text-primary">
              <input class="form-control" type="text" name="searchterm" value="" placeholder="Sök kund..." />
            </div>
            <div class="custom-control custom-control-inline col-2 col-lg-2">
              <input class="form-control btn btn-primary btn-sm rounded-lg" type="submit" value="Sök" />
            </div>
            <div class="form-check form-check-inline mx-2 pt-2 col-xl-2">
              <input class="form-check-input" type="checkbox" id="makulerade" name="makulerade" value="1" />
              <label class="form-check-label" for="makulerade">Makulerade</label>
            </div>
          </div>
        </form>
      </div>
    </div>
  </div>
</div>
<table id="invoices" class="table table-sm table-striped translate-middle-y">
  <thead class="end-0 bottom-0">
    <tr><th></th></tr>
  </thead>
  <tbody>
    <tr><td></td></tr>
  </tbody>
</table>

<button type="button" class="btn btn-primary position-relative">
Mails <span class="position-absolute top-0 start-100 translate-middle badge rounded-pill bg-secondary">+99 <span class="visually-hidden">unread messages</span></span>
</button>

<button type="button" class="btn btn-primary position-relative">
Alerts <span class="position-absolute top-0 start-100 translate-middle badge border border-light rounded-circle bg-danger p-2"><span class="visually-hidden">unread messages</span></span>
</button>


<select class="form-select form-select-sm" aria-label="Small select example">
  <option selected>Open this select menu</option>
  <option value="1">One</option>
</select>
<div class="btn-group d-block">
  <button type="button" class="btn btn-outline-primary">Action</button>
  <button type="button" class="btn btn-outline-primary dropdown-toggle dropdown-toggle-split" data-bs-toggle="dropdown" aria-expanded="false">
    <span class="visually-hidden">Toggle Dropdown</span>
  </button>
  <ul class="dropdown-menu p-2 px-2">
    <li><a class="dropdown-item" href="#">Action</a></li>
    <li><hr class="dropdown-divider mx-0"></li>
    <li><a class="dropdown-item" href="#">Separated link</a></li>
  </ul>
</div>
<ul class="list-group">
  <li class="list-group-item d-flex">
    <input class="form-check-input me-1" type="checkbox" value="" id="firstCheckboxStretched">
    <label class="form-check-label stretched-link w-auto flex-grow-1" for="firstCheckboxStretched">First checkbox</label>
  </li>
</ul>
<div class="collapse collapse-horizontal" id="collapseWidthExample">
    <div class="card card-body text-bg-danger" style="width: 300px;">
      This is some placeholder content for a horizontal collapse. It's hidden by default and shown when triggered.
    </div>
</div>
<a class="btn btn-primary" data-bs-toggle="offcanvas" href="#offcanvasExample" role="button" aria-controls="offcanvasExample">
  Link with href
</a>
<button class="btn btn-primary" type="button" data-bs-toggle="offcanvas" data-bs-target="#offcanvasExample" aria-controls="offcanvasExample">
  Button with data-bs-target
</button>

<div class="offcanvas offcanvas-start" tabindex="-1" id="offcanvasExample" aria-labelledby="offcanvasExampleLabel">
  <div class="offcanvas-header clearfix col-md-2">
    <h5 class="offcanvas-title bg-primary" id="offcanvasExampleLabel">Offcanvas</h5>
    <button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="Close"></button>
  </div>
  <div class="offcanvas-body">
    <div>
      Some text as placeholder. In real life you can have the elements you have chosen. Like, text, images, lists, etc.
    </div>
  </div>
</div>
<button type="button" class="btn btn-primary position-relative text-end">
  Profile
  <span class="position-absolute top-0 start-100 translate-middle p-2 bg-danger border border-light
badge rounded-pill rounded-circle">
    <span class="visually-hidden">New alerts</span>
  </span>
</button>

<div class="card" style="width: 18rem;">
  <div class="card-header top-50 me-2">p</div>
  <ul class="list-group list-group-flush">
    <li class="list-group-item fw-bold">An item</li>
  </ul>
  <div class="card-footer bg-warning text-dark">
    Card footer
  </div>
</div>

<div class="toast bg-light show" role="alert" data-bs-animation="true" data-bs-delay="3000" aria-live="assertive" aria-atomic="true">
  <div class="toast-header col">
    <strong class="me-auto toast-title bg-danger">p</strong>
    <small class="text-body-secondary toast-time mx-1">0</small>
    <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="<%== __('Close') %>"></button>
  </div>
  <div class="toast-body bg-success text-white" onclick="sprintf('Hi %.2f', 3.141); alert(shortbytes(12234556));">o
  </div>
</div>
<script>
  var data = [
    { name: { first: 'Josh', last: 'Jones' }, age: 30 },
    { name: { first: 'Carlos', last: 'Jacques' }, age: 19 },
    { name: { first: 'Carlos', last: 'Dante' }, age: 23 }
  ];
  data.sortBy('age');
</script>
<form action="/login" id="loginform" method="post" data-method="post" class="modal-content">
  <input type="hidden" name="test" value="get_login_like" />
  <div class="modal-header">
    <h5 class="modal-title mr-auto" id="modaltitle"><%= __('Login') %></h5>
    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="<%= __('Close') %>"></button>
  </div>
  <div class="modal-body">
    <div class="form-group col-md-6">
      <div class="alert alert-light" role="alert" id="loginalert"></div>
      <label for="username"><%= __('Username') %></label>
      <input type="text" class="form-control" name="username" id="username" placeholder="<%= __('Enter username') %>" autocomplete="username" />
    </div>
    <div class="form-group col-md-6">
      <label for="password"><%= __('Password') %></label>
      <input type="password" class="form-control" name="password" id="password" placeholder="<%= __('Enter password') %>" autocomplete="current-password" />
    </div>
    <div class="form-check my-3 col-md-12">
      <input type="checkbox" class="form-check-input" name="rememberme" id="rememberme" />
      <label class="form-check-label" for="rememberme"><%= __('Keep me logged in') %></label>
    </div>
  </div>
  <div class="modal-footer">
    <div class="row">
      <div class="col-sm-9">
        <a href="/user/register.html" class="btn btn-primary"><%= __('New account') %></a>
        <a href="/login/lostpassword.html" class="btn btn-primary"><%= __('Lost password?') %></a>
      </div>
      <div class="col-sm-3">
        <button type="submit" id="submitlogin" class="btn btn-primary"><%= __('Log in') %></button>
      </div>
    </div>
  </div>
</form>
<div class="d-flex justify-content-between">...</div>
<div class="row">
  <div class="col-md-8" id="compose">
    <form class="row g-3 needs-validation" id="contactform" method="post">
      <div class="form-floating mb-3 col-md-6">
        <input type="text" class="form-control<%= $valid->{name} %>" id="name" name="name" value="<%== $formdata->{name} %>" placeholder="<%= __('Your name') %>" aria-describedby="name invalidname">
        <label for="name" class="form-label"><%= __('Your name') %></label>
        <div id="invalidname" class="invalid-feedback"><%= __('Empty name') %></div>
      </div>
      <div class="form-floating mb-3 col-md-6">
        <input type="email" class="form-control<%= $valid->{email} %>" id="email" name="email" value="<%== $formdata->{email} %>" placeholder="me@example.com" aria-describedby="email invalidemail">
        <label for="email" class="form-label"><%= __('Your email') %></label>
        <div id="invalidemail" class="invalid-feedback"><%= __('Enter valid email') %></div>
      </div>
      <div class="form-floating mb-3 col-md-12">
        <input type="text" class="form-control<%= $valid->{subject} %>" id="subject" name="subject" value="<%== $formdata->{subject} %>" placeholder="<%= __('Subject') %>" aria-describedby="invalidsubject">
        <label for="subject" class="form-label"><%= __('Subject') %></label>
        <div id="invalidsubject" class="invalid-feedback"><%= __('Empty subject') %></div>
      </div>
      <div class="form-floating mb-3 col-md-12 sgrow-wrap">
        <textarea class="form-control<%= $valid->{message} %>" placeholder="<%= __('Message') %>" id="message" name="message" style="height: 200px" aria-describedby="invalidmessage"><%== $formdata->{message} %></textarea>
        <label for="message"><%= __('Message') %></label>
        <div id="invalidmessage" class="invalid-feedback"><%= __('Empty message') %></div>
      </div>
      <div class="form-floating mb-3 col-md-6">
        <input type="text" class="form-control<%= $valid->{captcha} %>" id="captcha" name="captcha" placeholder="captcha" aria-describedby="invalidcaptcha" />
        <label for="captcha" class="form-label"><%= __('Captcha code from image') %></label>
        <div id="invalidcaptcha" class="invalid-feedback"><%= __('Captcha was wrong') %></div>
      </div>
      <div class="form-floating mb-3 col-md-6">
        <img src="/captcha.png" class="img-fluid" alt="<%== __('Captcha image') %>" height="<%= config->{captcha}->{height} %>" width="<%= config->{captcha}->{width} %>" />
      </div>
      <div class="col-12" id="ip"><%= __x('Your ip {ip} will be appended to the message.', ip => $formdata->{ip}) %></div>
      <button type="submit" class="btn btn-primary">
        <span class="mx-2"><%== __('Send now') %></span>
        <%== icon 'send-fill', {} %>
      </button>
    </form>
  </div>
  <div class="col-md-4">
    <img src="/media/images/pexels-markus-winkler-4144772.jpg" class="img-fluid" />
  </div>
</div>
<form class="row row-cols-lg-auto g-3 align-items-center" id="dataform">
  <div class="col-12">
    <div class="input-group">
      <input type="date" class="form-control">
      <input type="text" class="form-control">
      <button type="submit" class="btn btn-primary mb-3"></button>
    </div>
  </div>
  <div class="col-12 col-me col-auto">
    <div class="input-group">
      <button type="submit" class="btn btn-primary mb-3"></button>
    </div>
  </div>
</form>