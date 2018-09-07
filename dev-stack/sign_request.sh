##
## Return the headers to use in curl
##

## Positional parameters:
## URL -- the URL to preform curl
## USER_ID -- the user who is making the request
## APIKEY -- the apiKey used to sign request

URL=$1
USER_ID=$2
APIKEY=$3

protocol="$(echo $URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
# remove the protocol from url
url="$(echo ${URL/$protocol/})" 
path=/$(echo $url | grep / | cut -d/ -f2-)

sig_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
sig_data="$USER_ID$path$sig_timestamp"

# echo -n to not include new line character
decoded_key=$(echo -n $APIKEY | base64 --decode)

signature_raw=$(echo -n "$sig_data" | iconv -t UTF8 | openssl dgst -sha1 -hmac "$decoded_key")
prefix_to_remove="(stdin)= " 
signature="$(echo -n ${signature_raw#$prefix_to_remove} | base64)" 

echo -H \"userId:$USER_ID\" -H \"signatureTimestamp:$sig_timestamp\" -H \"signature:$signature\"
