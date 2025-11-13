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