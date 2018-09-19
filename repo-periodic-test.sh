#!/bin/bash

# This script is useful to force codeship to periodically rerun a suite of tests.
# Method:
# Configure github to push all commits to codeship.
# Choose a branch name on github that is 'special'
# Configure codeship to run the desired tests when the 'special' branch name is pushed
# Define a github user who has write privilege on the target repo
#
# This script can be used to have early notice that a future browser version breaks a frontend, by forcing the repo
# to run frontend tests on a given branch on codeship (hint: saucelabs)
# ('canary' browsers are dev or beta browser builds that demonstrate future functionality)
# The separate branch allows master branch to be inviolate.

tempGitLocationDefault="/tempgit"
fileTouchDefault=".touch"
commitMessageDefault="run the tests on the canary browsers"
jobName=`basename "$0"` # this job

if [[ -z ${GITHUB_USER_EMAIL} ]] ; then
    echo "FATAL ERROR on ${jobName}: github user email is not set"
    exit 1
fi

if [[ -z ${GITHUB_ORG_NAME} ]] ; then
    echo "FATAL ERROR on ${jobName}: github organisation name is not set"
    exit 1
fi

if [[ -z ${GITHUB_REPO_NAME} ]] ; then
    echo "FATAL ERROR on ${jobName}: github repo name is not set"
    exit 1
fi

if [[ -z ${REPO_BRANCH_NAME} ]] ; then
    echo "FATAL ERROR on ${jobName}: github repo branch name is not set"
    exit 1
fi

if [[ -z ${GITHUB_USER_TOKEN} ]] ; then
    echo "FATAL ERROR on ${jobName}: github access token is not set"
    exit 1
fi

if [[ -z ${GITHUB_USER_NAME} ]] ; then
    echo "FATAL ERROR on ${jobName}: github user name is not set"
    exit 1
fi

if [[ -z ${TOUCH_FILE_NAME} ]] ; then
    TOUCH_FILE_NAME=${fileTouchDefault}
fi

if [[ -z ${TEMP_GIT_LOCATION} ]] ; then
    TEMP_GIT_LOCATION=${tempGitLocationDefault}
fi

if [[ -z ${COMMIT_MESSAGE} ]] ; then
    COMMIT_MESSAGE=${commitMessageDefault}
fi

# make a temp dir for git cloning
if [ ! -d ${TEMP_GIT_LOCATION} ]; then
    mkdir ${TEMP_GIT_LOCATION}
fi
cd ${TEMP_GIT_LOCATION}

export GIT_MERGE_AUTOEDIT="no" # we dont want the git merge-comment prompt

# Enable Slack WebHook Notification if ENVs are set
slackNotify=false
if ! [[ -z $SLACK_WEBHOOK ]] ; then
    slackNotify=true
    if [[ -z $SLACK_CHANNEL ]] ; then slackNotify=false ; fi
    if [[ -z $SLACK_BOTNAME ]] ; then SLACK_BOTNAME="${jobName}" ; fi
fi

# Failure function
failure () {
    errorMessage="$1"
    echo "ERROR: ${errorMessage}"
    if [[ $slackNotify == "true" ]] ; then
        slackPreText="Canary Browser Test Failure:"
        slackMessage="FATAL ERROR: ${jobName} - ${errorMessage}!"
        slackColour="#FF0000"
        echo "Posting Slack Notification to WebHook: $SLACK_WEBHOOK";
        slackPayload="payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_BOTNAME}\", \"attachments\":[{\"fallback\":\"${slackPreText} ${slackMessage}\", \"pretext\":\":fire::fire:*${slackPreText} ${slackMessage}*:fire::fire:\", \"color\":\"${slackColour}\", \"mrkdwn_in\":[\"text\", \"pretext\"], \"fields\":[{\"title\":\"Error Mesage\", \"value\":\"${errorMessage}\", \"short\":false}]}] }"
        CURL_RESULT=`curl -s -S -X POST --data-urlencode "$slackPayload" $SLACK_WEBHOOK`
    fi
    exit 1
}

# clear out any previous attempts so we can clone
if [ -d "$GITHUB_REPO_NAME" ]; then
    rm -rf ${GITHUB_REPO_NAME}
fi

# clone the docs repo
git clone https://${GITHUB_USER_TOKEN}@github.com/${GITHUB_ORG_NAME}/${GITHUB_REPO_NAME}.git --quiet
result=$?
if [[ ! 0 == ${result} ]]; then
    failure "git clone failed for ${GITHUB_ORG_NAME}/${GITHUB_REPO_NAME}"
fi

cd ${GITHUB_REPO_NAME}

# cant set the git id until we are in a git directory
git config user.name "${GITHUB_USER_NAME}"
git config user.email "${GITHUB_USER_EMAIL}"

git checkout ${REPO_BRANCH_NAME} --quiet
result=$?
if [[ 0 == ${result} ]]; then
    # the branch exists - update it
    git pull origin ${REPO_BRANCH_NAME} --quiet
    result=$?
    if [[ ! 0 == ${result} ]]; then
        failure "git pull for ${REPO_BRANCH_NAME} failed for ${GITHUB_ORG_NAME}/${GITHUB_REPO_NAME}"
    fi
else
    # the branch does not exist - create it
    git checkout -b ${REPO_BRANCH_NAME} --quiet
    result=$?
    if [[ ! 0 == ${result} ]]; then
        failure "git checkout failed for ${REPO_BRANCH_NAME} on ${GITHUB_ORG_NAME}/${GITHUB_REPO_NAME}"
    fi
fi

# get rid of any old touch files - keep the repo clean
if ls ${TOUCH_FILE_NAME}* 1> /dev/null 2>&1; then
    rm ${TOUCH_FILE_NAME}*
fi

# merge the latest master into our branch
mergeOutput=$(git merge master --no-edit)
result=$?
if [[ ! 0 == ${result} ]]; then
    failure "git merge from master to ${REPO_BRANCH_NAME} failed for ${GITHUB_ORG_NAME}/${GITHUB_REPO_NAME}"
fi

if [[ "$mergeOutput" == "Already up to date." ]]; then
    # nothing changed in master
    # add a new temp file to git, so we can commit & push a change
    touch ${TOUCH_FILE_NAME}-`date '+%Y-%m-%d-%H:%M:%S'`

    # -A will also commit our touch file changes
    git add -A
    result=$?
    if [[ ! 0 == ${result} ]]; then
        failure "git add failed for ${GITHUB_ORG_NAME}/${GITHUB_REPO_NAME}"
    fi

    git commit -m "${COMMIT_MESSAGE} (${jobName})" --quiet
    result=$?
    if [[ ! 0 == ${result} ]]; then
        failure "git commit failed for ${GITHUB_ORG_NAME}/${GITHUB_REPO_NAME}"
    fi
fi

git push origin HEAD:${REPO_BRANCH_NAME} --quiet
result=$?
if [[ ! 0 == ${result} ]]; then
    failure "git push failed for ${GITHUB_ORG_NAME}/${GITHUB_REPO_NAME}"
fi

# the dummy change on the canary branch has now been pushed to github, which will send it to codeship to run the tests on the canary browsers...

# we could delete this branch after the job is pushed to codeship
# reasons for: get rid of extra branches for a cleaner repo
# reasons against: when we do get a problem in codeship, confusion on how to see the source that caused it
# (it will match master, but... confusion) and cant quickly run it again if it fails, as the branch would be gone
# 'against' wins

