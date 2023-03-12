package Test::Mojo::Role::UserData;

use Mojo::Base -role, -signatures;

# ToDo: fix testing of userdata cookie after login. Used in 03-login.t
sub userdata_has ($self, $value, $desc = "Displayname: $value") {
  return $self->test('has', $value, $desc);
}


1;