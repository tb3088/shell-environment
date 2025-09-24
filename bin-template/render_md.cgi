#!/bin/bash -re

# cribbed from https://gist.github.com/tsaarni/67222455916ac38d94e8
# ref: https://naereen.github.io/StrapDown.js/
#
# example .htaccess
# Action markdown /cgi-bin/render_md.cgi
# AddHandler markdown .md
# DirectoryIndex index.html index.md

echo -ne 'Content-type: text/html\r\n'
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
$(cat "$PATH_TRANSLATED")
  </xmp>
  <script type="text/javascript" src="https://cdn.jsdelivr.net/gh/Naereen/StrapDown.js@master/strapdown.min.js?nonnavbar=y&keepicon=1"></script>
  <!-- alt:
    https://lbesson.bitbucket.io/md/strapdown.min.js
    https://raw.githubusercontent.com/Naereen/StrapDown.js/refs/heads/master/strapdown.min.js
  -->
</body>
</html>
__DOCUMENT
