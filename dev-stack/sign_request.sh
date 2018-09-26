##
## Return the headers to use in curl
##

## Positional parameters:
## URL -- the URL to preform curl without the query parameters
## USER_ID -- the user who is making the request
## APIKEY -- the apiKey used to sign request

URL=$1
USER_ID=$2
APIKEY=$3

# Requirements for signing request
# The provided APIKEY are base64 encoded and must be decoded to sign
# The signature must be base64 encoded

protocol="$(echo $URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
# remove the protocol from url
url="$(echo ${URL/$protocol/})" 
# path should start with /repo/v1
path="/$(echo $url | grep / | cut -d/ -f2-)"

sig_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
sig_data="$USER_ID$path$sig_timestamp"

# echo -n to not include new line character
decoded_key=$(echo -n $APIKEY | base64 --decode)

signature=$(echo -n $sig_data | openssl dgst -binary -sha1 -hmac "$decoded_key" | base64)

echo -H \"userId:$USER_ID\" -H \"signatureTimestamp:$sig_timestamp\" -H \"signature:$signature\"
