document.querySelector('#cardcol-<%== $service %> h5.card-header').innerHTML = `<%== __('Account') %>`;

const accountSearchForm = document.getElementById('accountSearchForm');
const searchTypeActions = {
  user: '<%= url_for("account_index") %>',
  group: '<%= url_for("account_group") %>',
  privilege: '<%= url_for("account_index") %>',
};

accountSearchForm.addEventListener('submit', function(e) {
  const searchType = accountSearchForm.querySelector('input[name="searchtype"]:checked').value;
  accountSearchForm.action = searchTypeActions[searchType] || searchTypeActions.user;
});
