# CSS

Directory for css.

This file has some html that normally doesn't get cached (eg. dynamically inserted) . It helps PurgeCSS knowing
what css not to remove.


#### Modal for login

<p class="show"></p>
<form action="/login" id="loginform" method="post" data-method="post" class="modal-content">
  <input type="hidden" name="test" value="get_login_like" />
  <div class="modal-header">
    <h5 class="modal-title mr-auto" id="modaltitle"></h5>
    <button type="button" class="close" data-bs-dismiss="modal" aria-label="">
      <span aria-hidden="true">&times;</span>
    </button>
  </div>
  <div class="modal-body">
    <div class="form-group">
      <div class="alert alert-light" role="alert" id="loginalert"></div>
      <label for="username"></label>
      <input type="text" class="form-control" name="username" id="username" placeholder="" autocomplete="username" />
    </div>
    <div class="form-group">
      <a href="/login/lostpassword.html" style="float: right;"></a>
      <label for="password"></label></label>
      <input type="password" class="form-control" name="password" id="password" placeholder="" autocomplete="current-password" />
    </div>
    <div class="form-check">
      <input type="checkbox" class="form-check-input" name="rememberme" id="rememberme" />
      <label class="form-check-label" for="rememberme"></label>
    </div>
  </div>
  <div class="modal-footer">
    <a href="/user/register.html" class="btn btn-primary" role="button"></a>
    <button type="submit" class="btn btn-primary"></button>
  </div>
</form>