#!/bin/bash

PLAN_OUTPUT="${PLUGIN_TERRAFORM_PLAN_OUTPUT:-terraform.plan}"

function slack_notify {
    MESSAGE="$(terraform show -no-color $PLAN_OUTPUT |sed 's/^ \+//g')"

    ADDITIONS=$(echo "$MESSAGE" |grep -cE "^[+] ")
    CHANGES=$(echo "$MESSAGE" |grep -cE "^[+-]/[-+] ")
    DESTROYED=$(echo "$MESSAGE" |grep -cE "^[-] ")

    if [ ${DESTROYED:-0} -gt 0 ]; then
        COLOR="#db1515"
    elif [ ${CHANGES:-0} -gt 0 ]; then
        COLOR="#e2df06"
    elif [ ${ADDITIONS:-0} -gt 0 ]; then
        COLOR="#2eb886"
    else
        COLOR="#4f4e49"
        MESSAGE="No changes detected!"
    fi

    curl -so /dev/null "$PLUGIN_SLACK_URL" --data "$(echo "$MESSAGE" |jq -Rs --arg apply "$PLUGIN_APPLY" --arg drone_build "$DRONE_BUILD_LINK" --arg color "$COLOR" \
      --arg add ${ADDITIONS:-0} --arg rm ${DESTROYED:-0} --arg changed ${CHANGES:-0} '{
        "channel":"#kubernetes",
        "icon_emoji": ":terraform:",
        "username": (if $apply == "true" then "Terraform Deployer" else "Terraform Planner" end),
        "attachments": [
            {
                "color": $color,
                "title": ((if $apply == "true" then "Deployed" else "Planned" end) + " terraform infrastructure changes"),
                "title_link": $drone_build,
                "text": ((if $apply == "true" then "*Deployed:* \($add) added, \($changed) changed, \($rm) destroyed:" else "*Plan:* \($add) to add, \($changed) to change, \($rm) to destroy:" end) + "\n\n" + .),
            }
        ]
    }')"
}

if [ ! -z "$PLUGIN_ROOT" ]; then
    cd "$PLUGIN_ROOT"
fi

if [ "$PLUGIN_APPLY" == "true" ]; then
    if [ ! -f "${PLAN_OUTPUT}" ]; then
        echo "No plan!"
        exit
    fi

    set -e
    terraform apply -input=false "${PLAN_OUTPUT}" ${PLUGIN_TERRAFORM_ARGS:-}
    set +e

    slack_notify
    rm "${PLAN_OUTPUT}"
else
    terraform plan -input=false -out="${PLAN_OUTPUT}" -detailed-exitcode ${PLUGIN_TERRAFORM_ARGS:-}
    EXIT_STATUS=${PIPESTATUS[0]}

    if [ $EXIT_STATUS -eq 0 ]; then
        echo "No changes detected, reseting plan output."
        git checkout "${PLAN_OUTPUT}"
    elif [ $EXIT_STATUS -eq 2 ]; then
        echo "Changes detected."
    else
        echo "Failing build due to terraform plan failure."
        exit 1
    fi

    slack_notify
fi
