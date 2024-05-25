# System integration

This directory contains examples of how to integrate the Samizdat application on a Ubuntu 20.04 installation.

#### /etc/systemd/system/samizdat.service - systemd configuration

    
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
    

### Enable and start

    
    systemctl enable samizdat
    systemctl start samizdat
    

### /etc/nginx/sites-available/samizdat.conf

We run our application behind an Nginx proxy. If they are on the same machine we can use a
unix socket. Also, we let nginx take care of content that already is on disk.

<pre>
    {{./nginx/sites-available/samizdat.conf}}
</pre>

### Enable and start

    
    cd /etc/nginx/sites-enabled
    ln -s ../sites-availabled/samizdat.conf .
    systemctl restart nginx
