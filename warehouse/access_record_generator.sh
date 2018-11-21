## This script insert a fake access record to a test S3 bucket at the time it runs.
## The record are put at a location that mirror the prod access record bucket's structure.
##
## Required environment variables:
## ACCESS_RECORD_BUCKET -- the bucket to put the record
## AWS_ACCESS_KEY_ID -- the aws access key of an account that has write access to the bucket
## AWS_SECRET_ACCESS_KEY -- the aws secret access key of an account that has write access to the bucket

# install aws cli
pip install awscli --upgrade --user
aws --version

# current time in miliseconds
timestamp=$(date +%s000)
# current date in yyyy-mm-dd format
date_string=$(date +%F)
# current date in hh-mm-ss-mls format
hours=$(date +"%H-%M-%S-000")
# stack number (74 65 73 74  is hex form of "test")
stack=074657374
# UUID
uuid=$(uuidgen)

# S3 path
# stack/date
s3_path=$stack/$date_string

# data
# ,"3","1539043204179",,"10.21.72.88","49","ELB-HealthChecker/2.0",,"63333df5-b569-4960-b393-30b37f33926e","10.21.1.138","/repo/v1/version","273950",,"2018-10-09","GET","66c1b1f963b4635e:-1ef27337:166552afa6d:-8000","000000242","dev","true","200"
data=",\"3\",\"$timestamp\",,\"10.21.72.88\",\"49\",\"ELB-HealthChecker/2.0\",,\"63333df5-b569-4960-b393-30b37f33926e\",\"10.21.1.138\",\"/repo/v1/fake\",\"273950\",,\"$date_string\",\"GET\",\"66c1b1f963b4635e:-1ef27337:166552afa6d:-8000\",\"$stack\",\"dev\",\"true\",\"200\""

# write to a file
# 00-00-04-577-5f257193-49a8-45e7-9691-c85eeabda814-rolling.csv
file_name=$hours-$uuid-rolling.csv
touch $file_name
echo $data > $file_name

# zip the file
gzip $file_name
zip_file=$file_name.gz

# push
aws s3api put-object --bucket $ACCESS_RECORD_BUCKET --key $s3_path/$zip_file --body $zip_file --acl public-read
