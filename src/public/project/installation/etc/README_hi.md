[description]: # "Configuration for various daemons supporting the Samizdat application."
[keywords]: # "etc,nginx,systemd,configuration"

# सिस्टम एकीकरण

इस डायरेक्टरी में उदाहरण हैं कि कैसे समिज़दात एप्लिकेशन को उबंटू 20.04 इंस्टॉलेशन पर एकीकृत किया जाए।

#### /etc/systemd/system/samizdat.service - systemd कॉन्फ़िगरेशन

    
    [Unit]
    Description=Samizdat
    After=network.target
    
    [Service]
    Type=forking
    User=www-data
    WorkingDirectory=/sites/Samizdat
    PIDFile=/sites/Samizdat/bin/hypnotoad.pid
    ExecStart=hypnotoad ./bin/samizdat
    ExecReload=hypnotoad ./bin/samizdat
    KillMode=process
    
    [Install]
    WantedBy=multi-user.target
    

### सक्षम करें और शुरू करें

    
    systemctl enable samizdat
    systemctl start samizdat
    

### /etc/nginx/sites-available/samizdat.conf

हम अपना एप्लिकेशन एक Nginx प्रॉक्सी के पीछे चलाते हैं। यदि वे एक ही मशीन पर हैं तो हम एक
यूनिक्स सॉकेट का उपयोग कर सकते हैं। इसके अलावा, हम nginx को ऐसी सामग्री की देखभाल करने देते हैं जो पहले से ही डिस्क पर है।

<pre>
    {{./nginx/sites-available/samizdat.conf}}
</pre>

### सक्षम करें और शुरू करें

    
    cd /etc/nginx/sites-enabled
    ln -s ../sites-availabled/samizdat.conf .
    systemctl restart nginx