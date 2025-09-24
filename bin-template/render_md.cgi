#!/bin/bash -re

# cribbed from https://gist.github.com/tsaarni/67222455916ac38d94e8
# ref: https://naereen.github.io/StrapDown.js/
#
# example .htaccess
# Action markdown /cgi-bin/render_md.cgi
# AddHandler markdown .md
# DirectoryIndex index.html index.md


function http_error() {
  echo "Status: 400 Bad Request"
  echo -ne 'Content-type: text/plain\r\n'
  echo "Error: bad path or wrong format ($PATH_INFO)"
  exit 1
}

function http_ok() {
  echo "Status: 200 OK"
  echo -ne 'Content-type: text/plain\r\n'
}

function realpath() { readlink -e "$1"; }
#alt: cd "${1%/*}" && echo `pwd -P`/${1##*/}


# validate
DOCROOT=/var/www/html
real_path=`realpath "$PATH_TRANSLATED"` &&
    [[ "$real_path" =~ ^"${DOCROOT}"/ ]] &&
    file "$real_path" | grep -q 'ASCII text' || http_error


http_ok
cat << __DOCUMENT
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$(echo "${PATH_INFO##*/}")</title>
</head>

<body>
  <!-- themes from https://bootswatch.com/, omit='default'
    can use 'textarea' tag instead of 'xmp'
  -->
  <xmp theme="paper" style="display:none;">
<!-- don't indent the markdown payload -->
$(cat "${real_path:?}")
  </xmp>
  <script type="text/javascript" src="https://cdn.jsdelivr.net/gh/Naereen/StrapDown.js@master/strapdown.min.js?nonnavbar=y&keepicon=1"></script>
  <!-- alt:
    https://lbesson.bitbucket.io/md/strapdown.min.js
    https://raw.githubusercontent.com/Naereen/StrapDown.js/refs/heads/master/strapdown.min.js
  -->
</body>
</html>
__DOCUMENT

exit 0
