curl -Lv \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    -H "x-custom-auth: your-secret-value" \
    "https://d3vcy7wygnf0wa.cloudfront.net/index.html?nonce=$(date +%s)"