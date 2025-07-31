[description]: # "How Samizdat minimizes assets by using Webpack and PurgeCSS"
[keywords]: # "Webpack,optimization,PurgeCSS,treeshaking"

# वेबपैक

[बूटस्ट्रैप](https://getbootstrap.com/) में काफी बड़ी जावास्क्रिप्ट और सीएसएस फाइलें हैं। वेबपैक के साथ एक कस्टम पैकेज
बनाना काफी आसान है, और फिर उन भागों को हटा देना जो प्रोजेक्ट में उपयोग नहीं किए जाते हैं। इससे ट्रैफिक तेज
और हल्का हो जाता है, साथ ही कोड को पार्स और एक्जीक्यूट करने का समय भी कम हो जाता है।

* फ़ाइलों को न्यूनतम करने के लिए [वेबपैक](./webpack/) शुरू करें