# उबंटू (लिनक्स) के लिए स्थापना

डिस्क इमेज बनाने के लिए आपको पर्ल का नवीनतम संस्करण चाहिए। फिर मोजोलिशस पैकेज प्राप्त करें।
विभिन्न कार्यों को मेक द्वारा प्रबंधित किया जाता है। ये चरण सुझाव हैं:

* [उबंटू इंस्टॉलेशन](https://ubuntu.com/download/server) से शुरू करें
* सामग्री इंस्टॉल करने के लिए कमांड चलाएं। यह एक अच्छी-लेकिन-आवश्यक सूची है जिसे थोड़ा छोटा करने की आवश्यकता है।
  * sudo apt update
  * sudo apt install --yes cpanminus git make automake autoconf cmake wget libevdev-dev libhtml-tidy-perl
  * sudo apt install --yes mkisofs xorriso growisofs transmission-cli
  * sudo apt install --yes libwebp-dev libgif-dev libjpeg-dev libpng-dev libtiff-dev libheif-dev libgd-dev uuid-dev
  * sudo apt install --yes postgresql-client postgresql-server-dev-all redis-server libhiredis-dev libargon2-dev
  * sudo apt install --yes imagemagick librsvg2-bin librsvg2-dev pngquant
  * sudo apt install --yes nginx-full apache2-utils
  * sudo cpanm --reinstall EV
  * sudo cpanm --reinstall Mojolicious
  * sudo cpanm --reinstall Data::UUID
  * sudo cpanm --reinstall UUID
  * sudo cpanm --reinstall DateTime
  * sudo cpanm --reinstall WWW::YouTube::Download
  * sudo cpanm --reinstall Hash::Merge
  * sudo cpanm --reinstall Text::MultiMarkdown
  * sudo cpanm --reinstall Mojolicious::Plugin::LocaleTextDomainOO
  * sudo cpanm --reinstall Locale::TextDomain::OO::Extract
  * sudo cpanm --reinstall Imager
  * sudo cpanm --reinstall Imager::File::JPEG
  * sudo cpanm --reinstall Imager::File::GIF
  * sudo cpanm --reinstall Imager::File::PNG
  * sudo cpanm --reinstall Imager::File::TIFF
  * sudo cpanm --reinstall Imager::File::HEIF
  * sudo cpanm --reinstall Imager::File::WEBP
  * sudo cpanm --reinstall MojoX::MIME::Types
  * sudo cpanm --reinstall IO::Compress::Gzip
  * sudo cpanm --reinstall Test::Harness
  * sudo cpanm --reinstall Mojo::Redis
  * sudo cpanm --reinstall Mojo::Pg
  * sudo cpanm --reinstall Business::Tax::VAT::Validation
  * sudo cpanm --reinstall Future::AsyncAwait
  * sudo cpanm --reinstall Bytes::Random::Secure::Tiny
  * sudo cpanm --reinstall Crypt::Argon2
  * sudo cpanm --reinstall Crypt::PBKDF2
  * sudo cpanm --reinstall Digest::SHA1
  * sudo cpanm --reinstall App::bmkpasswd
  * sudo cpanm --reinstall Mojolicious::Plugin::Captcha
  * sudo cpanm --reinstall Mojolicious::Plugin::Mail
  * sudo cpanm --reinstall Mojolicious::Plugin::Util::RandomString
* प्रोजेक्ट को एक उपयुक्त डायरेक्टरी में क्लोन करें, हम /sites का उपयोग करते हैं
  * sudo mkdir /sites
  * cd /sites
  * sudo -u www-data git clone https://github.com/FakenewsCom/Samizdat.git
  * cd Samizdat
* samizdat.dist.yml को samizdat.yml में कॉपी करें और अपनी आवश्यकताओं के लिए इसे संशोधित करें
* यदि आप अनुकूलन के लिए [वेबपैक](../webpack/) का उपयोग करना चाहते हैं:
  * curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash - && sudo apt-get install -y nodejs
  * make install

## संचालन

ये कार्य मेकफ़ाइल में परिभाषित हैं और एप्लिकेशन रूट डायरेक्टरी से चलाने के लिए बनाए गए हैं

* make static - मार्कडाउन फ़ाइलों को संसाधित करें
* make harvest - हमारे स्रोतों की सूची से सामग्री प्राप्त करने के लिए वेब क्रॉलर शुरू करें
* make clean - पब्लिक डायरेक्टरी से सभी HTML और मीडिया फ़ाइलें हटाएं
* make iso - पब्लिक डायरेक्टरी के डिस्क पर आकार की गणना करता है और DVD या ब्लू-रे ISO छवि बनाता है
* make torrent - पब्लिक डायरेक्टरी की एक टॉरेंट फ़ाइल बनाता है। यदि पाइरेट बे लॉगिन क्रेडेंशियल्स [samizdat.yml](../../../../samizdat.yml) में परिभाषित हैं, तो टॉरेंट फ़ाइल भी प्रकाशित की जाएगी।
* make isotorrent - मौजूदा ISO छवियों के लिए टॉरेंट फ़ाइलें बनाता है।
* make devtools - एक उबंटू लाइव छवि को बूटस्ट्रैप करता है जिसमें योगदान को आसान बनाने के लिए सब कुछ स्थापित है
* make i18n  - स्क्रिप्ट अंतर्राष्ट्रीयकरण का प्रबंधन करें
* make debug - मोर्बो वेब सर्वर शुरू करें। इसमें डीबगिंग के लिए बहुत सारी उपयोगी जानकारी है

## एकीकरण

तेज और स्थिर स्थापना को जल्दी से तैनात करने के लिए [कॉन्फ़िगरेशन उदाहरण](./etc/) का अन्वेषण करें।