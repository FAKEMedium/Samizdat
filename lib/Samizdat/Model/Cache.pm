package Samizdat::Model::Cache;

# A simple module for caching data used during a session

use Mojo::Base -base, -signatures;
use Mojo::JSON qw(decode_json encode_json);
use Crypt::AuthEnc::GCM;
use Crypt::PRNG qw(random_bytes);
use MIME::Base64 qw(encode_base64 decode_base64);

has 'redis';
has 'session';
has 'config';


# Get session-specific Redis key
sub _getSessionKey ($self, $key) {
  return $key unless $self->session;

  # If we have a session, make it session-specific
  if ($self->session->{cache_session_id}) {
    return $key . ':session:' . $self->session->{cache_session_id};
  }

  # Generate a session ID if we don't have one
  my $session_id = encode_base64(random_bytes(16), '');
  $session_id =~ s/[^a-zA-Z0-9]//g;  # Remove special chars
  $self->session->{cache_session_id} = $session_id;
  return $key . ':session:' . $session_id;
}


# Get or create encryption key from session
sub _getEncryptionKey ($self) {
  return undef unless $self->session;

  # Check if session already has an encryption key
  my $key = $self->session->{cache_encrypt_key};

  if (!$key) {
    # Generate new 256-bit (32-byte) key for AES-256
    $key = encode_base64(random_bytes(32), '');
    $self->session->{cache_encrypt_key} = $key;
  }

  return decode_base64($key);
}


# Encrypt data for Redis storage
sub _encrypt ($self, $data) {
  my $key = $self->_getEncryptionKey();
  return $data unless $key;  # If no session, store unencrypted (fallback)

  my $iv = random_bytes(12);  # 96-bit IV for GCM
  my $gcm = Crypt::AuthEnc::GCM->new('AES', $key, $iv);

  my $ciphertext = $gcm->encrypt_add($data);
  my $tag = $gcm->encrypt_done();

  # Return: encrypted marker + IV + tag + ciphertext (all base64 encoded)
  # Format: ENC1:iv_base64:tag_base64:ciphertext_base64
  return 'ENC1:' . encode_base64($iv, '') . ':' . encode_base64($tag, '') . ':' . encode_base64($ciphertext, '');
}


# Decrypt data from Redis
sub _decrypt ($self, $encrypted) {
  # Check if data is encrypted (starts with ENC1:)
  return $encrypted unless $encrypted =~ /^ENC1:/;

  my $key = $self->_getEncryptionKey();
  return '' unless $key;  # No key available, can't decrypt

  # Remove ENC1: prefix and split
  $encrypted =~ s/^ENC1://;
  my ($iv_b64, $tag_b64, $ciphertext_b64) = split(':', $encrypted, 3);

  my $iv = decode_base64($iv_b64);
  my $tag = decode_base64($tag_b64);
  my $ciphertext = decode_base64($ciphertext_b64);

  my $plaintext;
  eval {
    my $gcm = Crypt::AuthEnc::GCM->new('AES', $key, $iv);
    $plaintext = $gcm->decrypt_add($ciphertext);
    $gcm->decrypt_done($tag) or die "Authentication tag verification failed";
  };

  # If decryption fails, return empty (cache will be regenerated)
  return '' if $@;

  return $plaintext;
}


# Get value from cache
sub get ($self, $key) {
  return undef unless $key;

  # Use session-specific key if session available
  my $redis_key = $self->_getSessionKey($key);

  my $value = $self->redis->db->get($redis_key);
  return undef unless $value;

  # Decrypt if encrypted
  $value = $self->_decrypt($value);
  return undef unless $value;

  # Try to decode JSON, return raw value if not JSON
  my $decoded;
  eval { $decoded = decode_json($value); };
  return $@ ? $value : $decoded;
}


# Set value in cache
sub set ($self, $key, $value, $ttl = undef) {
  return 0 unless $key;

  # Use session-specific key if session available
  my $redis_key = $self->_getSessionKey($key);

  # Encode as JSON if it's a reference
  my $encoded = ref($value) ? encode_json($value) : $value;

  # Encrypt before storing
  $encoded = $self->_encrypt($encoded);

  # Use configured default lifetime if no TTL specified and config exists
  if (!defined $ttl && $self->config && exists $self->config->{lifetime}) {
    $ttl = $self->config->{lifetime};
  }

  if (defined $ttl) {
    # Set with expiration time (in seconds)
    $self->redis->db->setex($redis_key => $ttl => $encoded);
  } else {
    # Set without expiration
    $self->redis->db->set($redis_key => $encoded);
  }

  return 1;
}


# Delete from cache
sub del ($self, $key) {
  return 0 unless $key;
  my $redis_key = $self->_getSessionKey($key);
  return $self->redis->db->del($redis_key);
}


# Check if key exists
sub exists ($self, $key) {
  return 0 unless $key;
  my $redis_key = $self->_getSessionKey($key);
  return $self->redis->db->exists($redis_key);
}


# Increment counter
sub incr ($self, $key) {
  return 0 unless $key;
  my $redis_key = $self->_getSessionKey($key);
  return $self->redis->db->incr($redis_key);
}


# Decrement counter
sub decr ($self, $key) {
  return 0 unless $key;
  my $redis_key = $self->_getSessionKey($key);
  return $self->redis->db->decr($redis_key);
}


# Get multiple keys at once
sub mget ($self, @keys) {
  return [] unless @keys;
  my @redis_keys = map { $self->_getSessionKey($_) } @keys;
  return $self->redis->db->mget(@redis_keys);
}


# Set expiration time on a key
sub expire ($self, $key, $seconds) {
  return 0 unless $key;
  my $redis_key = $self->_getSessionKey($key);
  return $self->redis->db->expire($redis_key => $seconds);
}

1;