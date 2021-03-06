# static.vcl -- Static File Caching for Varnish
#
# Copyright (C) 2013 DreamHost (New Dream Network, LLC)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

sub vcl_recv {
	# Remove cookies from the request (by client) for static files
	if (req.method ~ "^(GET|HEAD)$" && req.url ~ "\.(jpg|jpeg|webp|gif|png|svg|svgz|ico|css|zip|tgz|tbz|gz|rar|bz2|pdf|txt|tar|wav|ogg|ogv|webm|mp3|mp4|bmp|rtf|js|flv|swf|html|htm|woff|ttf|ttc|otf|eot)(\?.*)?$") {
		if (req.url ~ "nocache") {
			return(pass);
		}
		set req.url = regsub(req.url, "\?.*$", "");
		unset req.http.Cookie;
		return(hash);
	}
}

sub vcl_backend_response {
	if (bereq.method ~ "^(GET|HEAD)$" && bereq.url ~ "\.(jpg|jpeg|webp|gif|png|svg|svgz|ico|css|zip|tgz|tbz|gz|rar|bz2|pdf|txt|tar|wav|ogg|ogv|webm|mp3|mp4|bmp|rtf|js|flv|swf|html|htm|woff|ttf|ttc|otf|eot)$") {
		unset beresp.http.set-cookie;
		set beresp.ttl = 24h;
		set beresp.grace = 2m;
	}
}