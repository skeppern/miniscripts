vcl 4.0;

import directors;
import std;

backend lxweb01 {
        .host = "lxweb01.micronova.lan";
        .port = "80";
        .probe = {
                .request =
                        "GET /check.html HTTP/1.1"
                        "Host: checkserver.micronova.lan"
                        "User-agent: Varnish-Cache"
                        "Connection: close";
                .timeout = 1s;
                .interval = 5s;
                .window = 5;
                .threshold = 3;
        }
}

backend lxweb02 {
        .host = "lxweb02.micronova.lan";
        .port = "80";
        .probe = {
                .request =
                        "GET /check.html HTTP/1.1"
                        "Host: checkserver.micronova.lan"
                        "User-agent: Varnish-Cache"
                        "Connection: close";
                .timeout = 1s;
                .interval = 5s;
                .window = 5;
                .threshold = 3;
        }
}

backend micawin01 {
        .host = "micawin2012.micronova.lan";
        .port = "80";
        .probe = {
                .url = "/check.txt";
                .timeout = 1s;
                .interval = 5s;
                .window = 5;
                .threshold = 3;
        }
}

sub vcl_init {
        new lxweb = directors.round_robin();
        lxweb.add_backend(lxweb01);
        lxweb.add_backend(lxweb02);

        new micaweb = directors.round_robin();
        micaweb.add_backend(micawin01);
}

sub vcl_recv {
        set req.backend_hint = lxweb.backend();

        if (req.http.host ~ "chidi.se") {
                set req.backend_hint = micaweb.backend();
        }

        if (req.http.host ~ "dnspile.com") {
                return (pass);
        }

        if (req.http.X-Forwarded-For) {
                #set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
                set req.http.X-Forwarded-For = client.ip;
        } else {
                set req.http.X-Forwarded-For = client.ip;
        }

#       set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
#       set req.url = std.querysort(req.url);

#       if (req.http.Upgrade ~ "(?i)websocket") {
#               return (pipe);
#       }

        if (req.method == "PURGE") {
                if (client.ip ~ local) {
                        return(purge);
                } else {
                        return(synth(403, "Access denied."));
                }
        }

        if (req.method != "GET" &&
                req.method != "HEAD" &&
                req.method != "PUT" &&
                req.method != "POST" &&
                req.method != "TRACE" &&
                req.method != "OPTIONS" &&
                req.method != "PATCH" &&
                req.method != "DELETE") {
                        return (pipe);
        }

        if (req.method != "GET" && req.method != "HEAD") {
                return (pass);
        }


        if (req.url ~ "\#") {
                set req.url = regsub(req.url, "\#.*$", "");
        }
        if (req.url ~ "\?$") {
                set req.url = regsub(req.url, "\?$", "");
        }

        if (req.http.Accept-Encoding) {
                if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
                        unset req.http.Accept-Encoding;
                } elsif (req.http.Accept-Encoding ~ "gzip") {
                        set req.http.Accept-Encoding = "gzip";
                } elsif (req.http.Accept-Encoding ~ "deflate") {
                        set req.http.Accept-Encoding = "deflate";
                } else {
                        unset req.http.Accept-Encoding;
                }
        }

        if (req.http.Cache-Control ~ "(?i)no-cache" && client.ip ~ local) { # create the acl editors if you want to restrict the Ctrl-F5
                return(pass);
        }

        if (req.url ~ "^[^?]*\.(mp[34]|rar|tar|tgz|gz|wav|zip|bz2|xz|7z|avi|mov|ogm|mpe?g|mk[av])(\?.*)?$") {
                unset req.http.Cookie;
                return (hash);
        }

        if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|pdf|png|rtf|swf|txt|woff|xml)(\?.*)?$") {
                unset req.http.Cookie;
                return (hash);
        }

        return (hash);
}

sub vcl_pipe {
#       if (req.http.upgrade) {
#               set bereq.http.upgrade = req.http.upgrade;
#       }
        set bereq.http.Connection = "Close";

        return (pipe);
}

sub vcl_pass {
        return (fetch);
}


sub vcl_hash {
        hash_data(req.url);
        if (req.http.host) {
                hash_data(req.http.host);
        } else {
                hash_data(server.ip);
        }
        return (lookup);
}

sub vcl_backend_response {
        set beresp.grace = 20m;

       if (beresp.http.content-type ~ "text") {
               set beresp.do_gzip = true;
       }

        if (bereq.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|mp[34]|pdf|png|rar|rtf|swf|tar|tgz|txt|wav|woff|xml|zip)(\?.*)?$") {
                unset beresp.http.set-cookie;
                set beresp.ttl = 15m;
        }

        if (bereq.url ~ "^[^?]*\.(mp[34]|rar|tar|tgz|gz|wav|zip|bz2|xz|7z|avi|mov|ogm|mpe?g|mk[av])(\?.*)?$") {
                unset beresp.http.set-cookie;
                set beresp.do_stream = true;
                set beresp.do_gzip = false;
        }


#       if (beresp.status == 301 || beresp.status == 302) {
#               set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
#       }

        if (beresp.ttl <= 0s || beresp.http.Set-Cookie || beresp.http.Vary == "*") {
                set beresp.ttl = 120s;
                set beresp.uncacheable = true;
                return (deliver);
        }

        return (deliver);
}

sub vcl_hit {
        if (obj.ttl >= 0s) {
                return (deliver);
        }

        if (std.healthy(req.backend_hint)) {
                if (obj.ttl + 10s > 0s) {
                        set req.http.grace = "normal(limited)";
                        return (deliver);
                } else {
                        return(fetch);
                }
        } else {
                if (obj.ttl + obj.grace > 0s) {
                        set req.http.grace = "full";
                        return (deliver);
                } else {
                        return (fetch);
                }
        }

        return (fetch);
}

sub vcl_deliver {
        if (obj.hits > 0) {
                set resp.http.X-Cache = "HIT";
        } else {
                set resp.http.X-Cache = "MISS";
        }
        set resp.http.X-Cache-Hits = obj.hits;
        unset resp.http.X-Powered-By;
        unset resp.http.Server;
        unset resp.http.X-Drupal-Cache;
        unset resp.http.X-Varnish;
        unset resp.http.Via;
        unset resp.http.Link;
        return (deliver);
}

sub vcl_purge {
#       if (req.method != "PURGE") {
#               set req.http.X-Purge = "Yes";
#               return(restart);
#       }
}

sub vcl_synth {
        if (resp.status == 720) {
                # return (synth(720, "http://host/new.html"));
                set resp.status = 301;
                set resp.http.Location = resp.reason;
                return (deliver);
        } elseif (resp.status == 721) {
                # return (synth(720, "http://host/new.html"));
                set resp.status = 302;
                set resp.http.Location = resp.reason;
                return (deliver);
        }

        return (deliver);
}

sub vcl_fini {
        return (ok);
}

sub vcl_miss {
        return (fetch);
}

acl local {
        "localhost";
        "192.168.3.0/24";
        "192.168.4.0/25";
        "192.168.5.0/25";
        "192.168.5.128/25";
        "31.211.203.112/30";
}
