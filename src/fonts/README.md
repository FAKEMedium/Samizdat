# Fonts for Samizdat

This directory contains fonts used by Samizdat for various purposes, including locale-aware captcha generation.

## Included Fonts

### Star Jedi Outline
- **File**: `star-jedi-outline/StarJediOutline-y0xm.ttf`
- **Purpose**: Default captcha font for Latin scripts
- **License**: Freeware
- **Author**: Boba Fonts - Davide Canavero

### Noto Sans Fonts (Google)
All Noto fonts are licensed under the SIL Open Font License 1.1 (see LICENSE-NOTO.txt)

- **NotoSans-Regular-Full.ttf**
  - Purpose: Captcha for Russian (Cyrillic script)
  - Coverage: Latin, Cyrillic, Greek
  - Copyright: 2015-2022 Google LLC

- **NotoSansDevanagari-Regular.ttf**
  - Purpose: Captcha for Hindi (Devanagari script)
  - Coverage: Devanagari
  - Copyright: 2015-2022 Google LLC

- **NotoSansArabic-Regular.ttf**
  - Purpose: Captcha for Arabic
  - Coverage: Arabic script
  - Copyright: 2015-2022 Google LLC

- **NotoSansCJK-Regular.ttc**
  - Purpose: Captcha for Chinese (Mandarin)
  - Coverage: Chinese, Japanese, Korean
  - Copyright: 2015-2022 Google LLC

## Downloading Fonts

Run `make fetchfonts` to download the required Noto fonts. Note that some fonts (NotoSans-Regular-Full.ttf and NotoSansCJK-Regular.ttc) are copied from system fonts and may need to be installed separately:

```bash
# Ubuntu/Debian
sudo apt-get install fonts-noto-core fonts-noto-cjk

# FreeBSD
sudo pkg install noto-basic noto-sc
```

## License Compliance

When distributing Samizdat with these fonts:
- ✅ The fonts can be freely bundled with the application
- ✅ Commercial use is permitted
- ✅ Modification is allowed
- ✅ Include the LICENSE-NOTO.txt file
- ❌ Do not sell the fonts standalone

## More Information

- Noto Fonts: https://fonts.google.com/noto
- SIL Open Font License: https://scripts.sil.org/OFL
