#!/bin/sh
HTML_FILE="/usr/share/nginx/html/index.html"

envsubst '$DEPLOY_TYPE $COMMIT_VERSION' < "$HTML_FILE" > "$HTML_FILE".tmp && mv "$HTML_FILE".tmp "$HTML_FILE"