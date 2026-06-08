# Samizdat invoice templates

Samizdat uses latexmk to render PDF files. Currently the only supported paper size is A4,
with recipient address field printed right so invoices can be sent in C5H2 window envelopes.

index.tex tries to honour localization settings for language, currency and address formatting.

Addresses include country name if the recipient lives in a different country than the sender.