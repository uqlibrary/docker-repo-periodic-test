# docker-repo-periodic-test

Docker container that clones a named repo, copies master to a named branch and pushes back to github

This script is useful to force codeship to periodically rerun a suite of tests.

To use this to run tests on a repo:

* Configure the github repo to push all commits to codeship and note GITHUB_ORG_NAME and GITHUB_REPO_NAME
* Define a github user who has write privilege on the target repo and note GITHUB_USER_EMAIL, GITHUB_USER_NAME, GITHUB_USER_TOKEN
* Choose a branch name on github that is 'special' and note REPO_BRANCH_NAME
* Configure codeship to run the desired tests when the 'special' branch name is pushed
* Add/edit a Scheduled Task on ECS (ECS > Clusters > default > create) and set the environment variables
* Add a Schedule Target for the new repo to the Scheduled Task (and set an environment override for GITHUB_REPO_NAME if you want to test multiple repos)

This script can be used to have early notice that a future browser version breaks a frontend, by forcing the repo to run frontend tests on a given branch on codeship (hint: saucelabs)

('canary' browsers are dev or beta browser builds that demonstrate future functionality)

The separate branch allows master branch to be inviolate.

To push a change to this repo to live, make a release with an integer tag (use the next number). This will cause dockerhub to pick up the release and then you can update the release number on ECS (ECS change done manually atm).

### Requirements

2. Needs to have these details seeded via ENV vars:

`GITHUB_USER_EMAIL`=<GITHUB_USER_EMAIL> (must have write priv on the repo - a collaborator role is sufficient. Required)

`GITHUB_USER_NAME`=<GITHUB_USER_NAME> (makes the build on codeship more attributable. Required)

`GITHUB_USER_TOKEN`=<GITHUB_USER_TOKEN> (createable at github/UserSettings/DeveloperSettings/PersonalAccessTokens. Required)

`GITHUB_REPO_NAME`=<GITHUB_REPO_NAME> (the github repo to be used. Required)

`GITHUB_ORG_NAME`=<GITHUB_ORG_NAME> (the github organisation owning the repo. Required)

`REPO_BRANCH_NAME`=<REPO_BRANCH_NAME> (the github branch to be created/reused. Required)

`COMMIT_MESSAGE`=<COMMIT_MESSAGE> (Optional. The commit message to use, If missing will use default value. The job name is automatically added.)

`TOUCH_FILE_NAME`=<TOUCH_FILE_NAME> (if the repo has not changed, we cant push it, so we will touch an empty file to enable a push. Optional (we have a default value)

`TEMP_GIT_LOCATION`=<TEMP_GIT_LOCATION> (the location the git operations will happen at. Optional - has a default value)

`SLACK_CHANNEL=<SLACK_CHANNEL_NAME>` (Optional: if used must also specify SLACK_WEBHOOK)

`SLACK_WEBHOOK=<SLACK_WEBHOOK_URL>` (Optional: if used must also specify SLACK_CHANNEL)

`SLACK_BOTNAME=<SLACK_BOTNAME>` (Optional: defaults to job name)

Get your org's webhooks: https://slack.com/apps/A0F7XDUAZ-incoming-webhooks

### More reading:

* https://get.slack.help/hc/en-us/articles/115005265063-Incoming-WebHooks-for-Slack
* https://api.slack.com/incoming-webhooks

