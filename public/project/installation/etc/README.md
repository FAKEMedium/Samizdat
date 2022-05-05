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