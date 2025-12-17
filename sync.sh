#!/usr/bin/env bash
set -euo pipefail

TARGET=$1
INSTANCE_ID=$2

ssm_output() {
  local COMMAND_ID=$1

  STDOUT=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardOutputContent" \
    --output text)

  STDERR=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "StandardErrorContent" \
    --output text)

  echo "------ STDOUT ------"
  echo "${STDOUT}"
  echo "------ STDERR ------"
  echo "${STDERR}"
}

ssm_result() {
  local COMMAND_ID=$1
  local RETCODE=$2
  local EXIT_ON_FAIL=$3

  if [[ "$RETCODE" -eq 0 || "$EXIT_ON_FAIL" -eq 0 ]]; then
    echo "[$COMMAND_ID] Success"
    ssm_output $COMMAND_ID
  else
    echo "[$COMMAND_ID] Failed: exit code $RETCODE"
    ssm_output $COMMAND_ID
    exit 1
  fi
}

run_ssm() {
  local COMMAND="$1"
  local MASKED_CMD="${2:-}"
  local EXIT_ON_FAIL="${3:-1}"

  PARAMS_JSON=$(jq -cn --arg cmd "$COMMAND" '{commands: [$cmd]}')

  COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "$PARAMS_JSON" \
    --query "Command.CommandId" \
    --output text)

  echo "[$COMMAND_ID] Executing command: ${MASKED_CMD:-$COMMAND}"
  echo "[$COMMAND_ID] Waiting for completion"

  aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" >/dev/null 2>&1 || true

  RETCODE=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "ResponseCode")

  ssm_result $COMMAND_ID $RETCODE $EXIT_ON_FAIL
  return $RETCODE
}

file_exists() {
  local FILE_PATH="$1"
  # Do no allow script to exit 1 if file does not exist
  run_ssm "sudo -u ubuntu test -f $FILE_PATH" "" 0
  # run_ssm still returns 0/1 for exists/does not exist
  return $?
}

if [[ "$TARGET" == "library" ]]; then
  LOCAL_PATH="~/calibre-library"
  read -p "Local path [$LOCAL_PATH]: " INPUT_PATH
  LOCAL_PATH=${INPUT_PATH:-$LOCAL_PATH}
  # Expand leading ~ if present
  LOCAL_PATH="${LOCAL_PATH/#~/$HOME}"

  S3_PATH=s3://cweb-library
  EC2_PATH=/srv/library

  echo "Syncing local library to s3 bucket ..."
  aws s3 sync $LOCAL_PATH $S3_PATH --exclude ".*"

  echo "Stopping calibre-web ..."
  run_ssm "sudo docker stop calibre-web"

  echo "Syncing s3 library to ebs ..."
  run_ssm "sudo -u ubuntu aws s3 sync $S3_PATH $EC2_PATH --exact-timestamps"

  echo "Starting calibre-web ..."
  run_ssm "sudo docker start calibre-web"

  echo "Library sync complete."

elif [[ "$TARGET" == "config" ]]; then
  LOCAL_PATH=./local/config/app.db
  read -p "Local path [$LOCAL_PATH]: " INPUT_PATH
  LOCAL_PATH=${INPUT_PATH:-$LOCAL_PATH}

  ADMIN_USER=admin
  read -p "Admin user [$ADMIN_USER]: " INPUT_USER
  ADMIN_USER=${INPUT_USER:-$ADMIN_USER}

  read -sp "Admin pass: " ADMIN_PASS
  echo
  if [[ -z "$ADMIN_PASS" ]]; then
      echo "Admin password cannot be empty."
      exit 1
  fi

  EC2_DB_PATH=/srv/config/app.db
  EC2_BACKUP_PATH="$EC2_DB_PATH.bak"

  echo "Checking for db backup ..."
  if file_exists $EC2_BACKUP_PATH; then
    read -p "Backup exists. Overwrite backup? [y/N]: " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        echo "Aborting."
        exit 0
    fi
  else
    echo "No backup found. Continuing."
  fi

  CONFIG_BUCKET_NAME=cweb-config
  CONFIG_BUCKET_PATH="s3://$CONFIG_BUCKET_NAME"
  CONFIG_BUCKET_DB_PATH="$CONFIG_BUCKET_PATH/app.db"

  if ! aws s3api head-bucket --bucket $CONFIG_BUCKET_NAME >/dev/null 2>&1; then
    echo "Making temporary config bucket ..."
    aws s3 mb $CONFIG_BUCKET_PATH
  fi

  echo "Syncing local config to s3 bucket ..."
  aws s3 cp $LOCAL_PATH $CONFIG_BUCKET_DB_PATH

  echo "Generating a pre-signed url ..."
  PRESIGNED_URL=$(aws s3 presign $CONFIG_BUCKET_DB_PATH --expires-in 600)

  echo "Stopping calibre-web ..."
  run_ssm "sudo docker stop calibre-web"

  echo "Backing up current db ..."
  run_ssm "sudo -u ubuntu test -f $EC2_DB_PATH && sudo -u ubuntu mv $EC2_DB_PATH $EC2_BACKUP_PATH || true"

  echo "Downloading config from s3..."
  run_ssm "sudo wget \"$PRESIGNED_URL\" -O $EC2_DB_PATH && sudo chown 1000:1000 $EC2_DB_PATH"

  echo "Setting admin credentials ..."
  BASE_CMD="cd /srv/cweb-setup && sudo docker-compose run --rm calibre-web bash -c \"python3 /app/calibre-web/cps.py -p /config/app.db -s %s:%s\""
  COMMAND=$(printf "$BASE_CMD" "$ADMIN_USER" "$ADMIN_PASS")
  MASKED_CMD=$(printf "$BASE_CMD" "$ADMIN_USER" "*****")
  run_ssm "$COMMAND" "$MASKED_CMD"

  echo "Starting calibre-web ..."
  run_ssm "sudo docker start calibre-web"

  echo "Removing temporary config bucket ..."
  aws s3 rm $CONFIG_BUCKET_PATH --recursive
  aws s3 rb $CONFIG_BUCKET_PATH

  echo "Config sync complete."
else
  echo "Usage: sync.sh [library|config] <instance-id>"
  exit 1
fi