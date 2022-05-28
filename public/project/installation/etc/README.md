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

### /etc/nginx/sites-available/samizdat

We run our application behind an Nginx proxy. If they are on the same machine we can use a
unix socket. Also, we let nginx take care of content that already is on disk.

    upstream samizdat {
        # server 127.0.0.1:3000;
        server unix:/sites/Samizdat/bin/samizdat.sock;
    }

    server {
        listen 443 ssl http2 backlog=4096 default_server;
        listen [::]:443 ssl http2 backlog=4096 default_server;
        server_name _;
        
        include snippets/ssl-fakenews.com.conf;
        include snippets/ssl-params.conf;
        gzip_static on;
        
        root /sites/Samizdat/public;
        index index.html;
        client_max_body_size 30M;
        
        access_log /sites/Samizdat/log/combined.log combined buffer=64k flush=5m;
        error_log /sites/Samizdat/log/error.log;
        
        location / {
            disable_symlinks on;
            gzip_static on;
            gzip_proxied expired no-cache no-store private auth;
            try_files $uri $uri/index.html @samizdat;
        }

        location @samizdat {
            proxy_buffering off;
            proxy_pass http://samizdat;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
        
        location ~* \.(?:ico|css|js|jpe?g|png|gif|svg|pdf|mov|mp4|mp3|woff)$ {
            expires 8d;
            add_header Pragma public;
            add_header Cache-Control "public";
            gzip_vary on;
        }
        
        location /favicon.ico {
            log_not_found off;
            log_subrequest off; 
            access_log off;
        }
    }

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        root /sites/Samizdat/public;
        log_not_found off;
        log_subrequest off;
        access_log off;
        return 301 https://fakenews.com$request_uri;
    }

### Enable and start

    cd /sites/nginx/sites-enabled
    ln -s ../sites-availabled/samizdat .
    systemctl restart nginx