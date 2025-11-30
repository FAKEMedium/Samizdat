package Samizdat::Model::Public;

use Mojo::Base -base, -signatures;

has 'app';
has 'pg';

=head1 NAME

Samizdat::Model::Public - Public data access model

=head1 DESCRIPTION

This model provides access to public reference data such as languages and countries.

=head1 METHODS

=head2 languages

Get all languages as a hash mapping language code to language ID.

    my $languages = $public->languages();
    # Returns: { en => 1, sv => 2, ru => 3, ... }

=cut

sub languages ($self) {
  my $rows = $self->pg->db->query(
    'SELECT code, languageid FROM public.languages ORDER BY languageid'
  )->hashes->to_array;

  my %languages;
  for my $row (@$rows) {
    $languages{$row->{code}} = $row->{languageid};
  }

  return \%languages;
}

# Get languages with full details (languageid, code, title)
# Joins with languagenames to get the display name in the specified language (default: English/1)
# If $codes is provided (arrayref or hashref), only returns those languages
sub getLanguages ($self, $codes = undef, $display_languageid = 1) {
  my $sql = q{
    SELECT l.languageid, l.code, ln.languagename AS title
    FROM languages l
    LEFT JOIN languagenames ln ON l.languageid = ln.languageid AND ln.language = ?
  };
  my @params = ($display_languageid);

  if ($codes) {
    my @code_list = ref($codes) eq 'HASH' ? keys %$codes : @$codes;
    if (@code_list) {
      $sql .= ' WHERE l.code IN (' . join(',', map { '?' } @code_list) . ')';
      push @params, @code_list;
    }
  }

  $sql .= ' ORDER BY l.languageid';
  return $self->pg->db->query($sql, @params)->hashes->to_array;
}

=head2 countries

Get country data.

    my $countries = $public->countries();

=cut

sub countries ($self, $options = {}) {

}

1;

=head1 SEE ALSO

L<Samizdat::Plugin::Public>

=cut