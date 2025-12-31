# Info # 

The certificates in this directory are test certificates that can be
used when testing e.g. curl calls towards mss.

The payout test certificate is the only one that MSS is aware of and
**must** be used for signing payout requst payload. MSS will throw
error otherwise since it will not be able to verify the signature.
