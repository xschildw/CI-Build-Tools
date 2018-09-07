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

function extract_path{
	proto="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
	# remove the protocol
	url="$(echo ${1/$proto/})"
	echo $url | grep / | cut -d/ -f2-
}

path=$(extract_path $URL)

ISO_FORMAT="%Y-%m-%dT%H:%M:%S.000Z"
sig_timestamp="date -u +$ISOFORMAT"
sig_data="$USER_ID$path$sig_timestamp"

signature=$(echo -n "$sig_data" | openssl dgst -sha1 -hmac "$APIKEY")

echo -H 'userId: $USERID' -H 'signatureTimestamp: $sig_timestamp' -H 'signature: $signature'
