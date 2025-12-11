#!/usr/bin/env bash
set -euo pipefail

TARGET=$1
INSTANCE_ID=$2

ssm_result() {
  local COMMAND_ID=$1
  local RETCODE=$2

  if [[ "$RETCODE" -eq 0 ]]; then
    echo "Success [$COMMAND_ID]"
  else
    echo "Failed [$COMMAND_ID]: exit code $RETCODE"

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
    echo "$STDOUT"
    echo "------ STDERR ------"
    echo "$STDERR"

    exit 1
  fi
}

run_ssm() {
  local COMMAND=$1

  COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "{\"commands\": [\"$COMMAND\"]}" \
    --query 'Command.CommandId' \
    --output text)
  
  echo "Executing command [$COMMAND_ID]: $COMMAND"
  echo "Waiting for completion [$COMMAND_ID]"

  aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID"

  RETCODE=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "ResponseCode")

  ssm_result $COMMAND_ID $RETCODE
}

if [[ "$TARGET" == "library" ]]; then
  read -p "Local path [~/calibre-library]: " LOCAL_PATH
  LOCAL_PATH=${LOCAL_PATH:-~/calibre-library}

  echo "Syncing local library to s3 bucket ..."
  aws s3 sync $LOCAL_PATH s3://cweb-library --exclude ".*"

  echo "Syncing s3 library to ebs ..."
  run_ssm "sudo -u ubuntu aws s3 sync s3://cweb-library /srv/library"

elif [[ "$TARGET" == "config" ]]; then
  read -p "Local path [./local/config/app.db]: " LOCAL_PATH
  LOCAL_PATH=${LOCAL_PATH:-./local/config/app.db}
  read -p "Admin user [admin]: " ADMIN_USER
  ADMIN_USER=${ADMIN_USER:-admin}
  read -sp "Admin pass: " ADMIN_PASS

  echo "Syncing local app.db to s3 bucket ..."
  aws s3 cp $LOCAL_PATH s3://cweb-config/app.db

  echo "Stopping calibre-web ..."
  run_ssm "docker stop calibre-web"

  echo "Syncing s3 config to ebs ..."
  run_ssm "sudo -u ubuntu aws s3 sync s3://cweb-config /srv/config"

  echo "Setting admin credentials"
  run_ssm "docker compose run --rm calibre-web bash -c \"python3 /app/calibre-web/cps.py -p /config/app.db -s ${ADMIN_USER}:${ADMIN_PASS}\""

  echo "Starting calibre-web ..."
  run_ssm "docker start calibre-web"

else
  echo "Usage: sync.sh [library|config] <instance-id>"
  exit 1
fi