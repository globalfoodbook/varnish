#
# This is an example VCL file for Varnish from https://gist.github.com/jemekite/1921dad1b417d6b0a91c.
# BY https://github.com/jemekite
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and http://varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Update for work with Varnish 4


# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;
# import std;

backend default {
  .host = "${BACKEND_PORT_80_TCP_ADDR}";
  .port = "${BACKEND_PORT_80_TCP_PORT}";
	.probe = {
    #.url = "/"; # short easy way (GET /)
    # We prefer to only do a HEAD /
    .request =
      "HEAD / HTTP/1.1"
      "Host: ${VARNISH_HOST}"
      "Connection: close";

    .interval  = 500s; # check the health of each backend every 5 seconds
    .timeout   = 300s; # timing out after 1 second.
    .window    = 5;  # If 3 out of the last 5 polls succeeded the backend is considered healthy, otherwise it will be marked as sick
    .threshold = 3;
  }

  .first_byte_timeout     = 300s;   # How long to wait before we receive a first byte from our backend?
  .connect_timeout        = 300s;     # How long to wait for a backend connection?
  .between_bytes_timeout  = 10s;     # How long to wait between bytes received from our backend?

}


# Bad Bot detection script can be obtained here: https://github.com/abidkecil/varnish-bad-bot-detection
# include "/etc/varnish/conf.d/bad_bot_detection.vcl";
include "/etc/varnish/inc/bad_bot_detection.vcl";
sub vcl_recv {
  call bad_bot_detection;
}

import std;

include "/etc/varnish/inc/xforward.vcl";
include "/etc/varnish/inc/purge.vcl";
include "/etc/varnish/inc/bigfiles.vcl";        # Varnish 3.0.3+
include "/etc/varnish/inc/static.vcl";

acl purge {
	"localhost";
  "${BACKEND_PORT_80_TCP_ADDR}";
  "::1";
}


# Detect the device
sub detect_device {
  # Define the desktop device
  set req.http.X-Device = "desktop";

  if (req.http.User-Agent ~ "iP(hone|od)" || req.http.User-Agent ~ "Android" || req.http.User-Agent ~ "iPad") {
    # Define smartphones and tablets
    set req.http.X-Device = "smart";
  }

  elseif (req.http.User-Agent ~ "SymbianOS" || req.http.User-Agent ~ "^BlackBerry" || req.http.User-Agent ~ "^SonyEricsson" || req.http.User-Agent ~ "^Nokia" || req.http.User-Agent ~ "^SAMSUNG" || req.http.User-Agent ~ "^LG") {
    # Define every other mobile device
    set req.http.X-Device = "other";
  }
}



### WordPress-specific config ###
sub vcl_recv {
	call detect_device;
	# Handling CONNECT and Non-RFC2616 HTTP Methods
	# i.e. request method isn't one of the 'normal' web site or web service methods
	if (req.method !~ "^GET|HEAD|PUT|POST|TRACE|OPTIONS|DELETE$") {
		return(pipe);
	}

  if (req.url ~ "\.xml(\.gz)?$") {
   return (pass);
  }

	### Check for reasons to bypass the cache!
	# never cache anything except GET/HEAD
	if (req.method != "GET" && req.method != "HEAD") {
		return(pass);
	}
	# Don't cache when authorization header is being provided by client
	if (req.http.Authorization || req.http.Authenticate) {
		return(pass);
	}
	# don't cache logged-in users or authors
	if (req.http.Cookie ~ "wp-postpass_|wordpress_logged_in_|comment_author|PHPSESSID") {
		return(pass);
	}
	# don't cache ajax requests
	if (req.http.X-Requested-With == "XMLHttpRequest") {
		return(pass);
	}
	# don't cache these special pages, e.g. urls with ?nocache or comments, login, regiser, signup, ajax, etc.
	if (req.url ~ "nocache|wp-admin|wp-(comments-post|login|signup|activate|mail|cron)\.php|preview\=true|admin-ajax\.php|xmlrpc\.php|bb-admin|server-status|control\.php|bb-login\.php|bb-reset-password\.php|register\.php") {
		return(pass);
	}
	# avoid querysort wordpress script loading 
	if (req.url !~ "load-scripts\.php") {
 		set req.url = std.querysort(req.url);
	}

	### looks like we might actually cache it!
	# fix up the request
	set req.url = regsub(req.url, "\?replytocom=.*$", "");

	# Remove has_js, Google Analytics __*, and wooTracker cookies.
	set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(__[a-z]+|has_js|wooTracker)=[^;]*", "");
	set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
	if (req.http.Cookie ~ "^\s*$") {
		unset req.http.Cookie;
	}

	return(hash);
}

sub vcl_pipe {
	# Force every pipe request to be the first one.
	# https://www.varnish-cache.org/trac/wiki/VCLExamplePipe
	set bereq.http.connection = "close";
}

sub vcl_hash {
	# Add the browser cookie only if a WordPress cookie found.
	if (req.http.Cookie ~ "wp-postpass_|wordpress_logged_in_|comment_author|PHPSESSID") {
		hash_data(req.http.Cookie);
	}
}

# Invalidation with purge:
# In Varnish 4, cache invalidation with purges is now done via return(purge) from vcl_recv.
# The purge; keyword has been retired.
#
# sub vcl_hit {
# 	if (req.method == "PURGE") {
# 		purge;
# 		error 200 "Purged.";
# 	}
# }
#
# sub vcl_miss {
# 	if (req.method == "PURGE") {
# 		purge;
# 		error 200 "Purged.";
# 	}
# }

sub vcl_backend_response {
	# Don't store backend
	if (bereq.url ~ "nocache|wp-admin|admin|login|wp-(comments-post|login|signup|activate|mail|cron)\.php|preview\=true|admin-ajax\.php|xmlrpc\.php|bb-admin|server-status|control\.php|bb-login\.php|bb-reset-password\.php|register\.php") {
		set beresp.uncacheable = true;
		return (deliver);
	}
	# Otherwise cache away!
	if ( (!(bereq.url ~ "nocache|wp-admin|admin|login|wp-(comments-post|login|signup|activate|mail|cron)\.php|preview\=true|admin-ajax\.php|xmlrpc\.php|bb-admin|server-status|control\.php|bb-login\.php|bb-reset-password\.php|register\.php")) || (bereq.method == "GET") ) {
		unset beresp.http.set-cookie;
		set beresp.ttl = 2h;
	}

	# make sure grace is at least 2 minutes
	if (beresp.grace < 2m) {
		set beresp.grace = 2m;
	}

	# catch obvious reasons we can't cache
	if (beresp.http.Set-Cookie) {
		set beresp.ttl = 0s;
	}

	# Varnish determined the object was not cacheable
	if (beresp.ttl <= 0s) {
		set beresp.http.X-Cacheable = "NO:Not Cacheable";
		set beresp.uncacheable = true;
		return (deliver);

	# You don't wish to cache content for logged in users
	} else if (bereq.http.Cookie ~ "wp-postpass_|wordpress_logged_in_|comment_author|PHPSESSID") {
		set beresp.http.X-Cacheable = "NO:Got Session";
		set beresp.uncacheable = true;
		return (deliver);

	# You are respecting the Cache-Control=private header from the backend
	} else if (beresp.http.Cache-Control ~ "private") {
		set beresp.http.X-Cacheable = "NO:Cache-Control=private";
		set beresp.uncacheable = true;
		return (deliver);

	# You are extending the lifetime of the object artificially
	# } else if (beresp.ttl < 300s) {
	# 	set beresp.ttl   = 300s;
	# 	set beresp.grace = 300s;
	# 	set beresp.http.X-Cacheable = "YES:Forced";

	# Varnish determined the object was cacheable
	} else {
		set beresp.http.X-Cacheable = "YES";
	}

	# Avoid caching error responses
	if (beresp.status == 404 || beresp.status >= 500) {
		set beresp.ttl   = 0s;
		set beresp.grace = 15s;
	}

	# Deliver the content
	return(deliver);
}

sub vcl_deliver {

	# Remove unnecessary headers
	unset resp.http.Server;
	unset resp.http.X-Powered-By;
	unset resp.http.X-Varnish;
	unset resp.http.Via;

	# DIAGNOSTIC HEADERS
	if (obj.hits > 0) {
		set resp.http.X-Cache = "HIT";
	} else {
		set resp.http.X-Cache = "MISS";
	}

}
