#!/bin/bash

ENDPOINT_URL_OPTION=
if [ -n "$AWS_ENDPOINT_URL" ]; then
  ENDPOINT_URL_OPTION="--endpoint-url $AWS_ENDPOINT_URL"
fi

SECRET_STRING="$(aws $ENDPOINT_URL_OPTION secretsmanager get-secret-value --secret-id "$DB_SECRET_NAME" --query 'SecretString' --output text)"
DB_PASSWORD=$(echo "$SECRET_STRING" | jq -r '.db_password')
DB_USER=$(echo "$SECRET_STRING" | jq -r '.db_user')
DB_HOST=$(echo "$SECRET_STRING" | jq -r '.db_host')
DB_PORT=$(echo "$SECRET_STRING" | jq -r '.db_port')
DB_NAME=$(echo $DB_NAME)
