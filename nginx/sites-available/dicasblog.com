fastcgi_cache_path /home/sites/dicasblog.com/cache levels=1:2 keys_zone=dicasblog.com:100m inactive=60m;


server {
	listen 80;
	server_name www.dicasblog.com;

	return 301 $scheme://dicasblog.com$request_uri;
}

server {
    server_name dicasblog.com;

    access_log /home/sites/dicasblog.com/logs/access.log;
    error_log /home/sites/dicasblog.com/logs/error.log;

    root /home/sites/dicasblog.com/public/;
    index index.php;
    
	
	set $mobile_request 0;

if ($http_user_agent ~* "(2\.0 MMP|240x320|400X240|AvantGo|BlackBerry|Blazer|Cellphone|Danger|DoCoMo|Elaine\/3\.0|EudoraWeb|Googlebot-Mobile|hiptop|IEMobile|KYOCERA\/WX310K|LG\/U990|MIDP-2\.|MMEF20|MOT-V|NetFront|Newt|Nintendo Wii|Nitro|Nokia|Opera Mini|Palm|PlayStation Portable|portalmmm|Proxinet|ProxiNet|SHARP-TQ-GX10|SHG-i900|Small|SonyEricsson|Symbian OS|SymbianOS|TS21i-10|UP\.Browser|UP\.Link|webOS|Windows CE|WinWAP|YahooSeeker\/M1A1-R2D2|NF-Browser|iPhone|iPod|Android|BlackBerry9530|G-TU915 Obigo|LGE VX|webOS|Nokia5800)" ) {

	set $mobile_request 1;

}

    location / {
        try_files $uri $uri/ /index.php?$args; 
    }
    
    set $skip_cache 0;

	# POST requests and urls with a query string should always go to PHP
	if ($request_method = POST) {
	    set $skip_cache 1;
	}   
	if ($query_string != "") {
	    set $skip_cache 1;
	}   
	
	# Don’t cache uris containing the following segments
	if ($request_uri ~* "/wp-admin/|/xmlrpc.php|wp-.*.php|/feed/|index.php|sitemap(_index)?.xml") {
	    set $skip_cache 1;
	}   
	
	# Don’t use the cache for logged in users or recent commenters
	if ($http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
	    set $skip_cache 1;
	}

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_cache_bypass $skip_cache;
		fastcgi_no_cache $skip_cache;
		fastcgi_cache dicasblog.com;
		fastcgi_cache_valid 60m;
    }
    
    location ~ /purge(/.*) {
	    fastcgi_cache_purge dicasblog.com "$scheme$request_method$host$1";
	}
}