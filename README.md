Terraform plugin for Drone.

Allowed variables:

* `root`: the terraform directory.
* `apply`: if true, apply the changes, otherwise just plan.
* `slack_url`: Slack URL to submit Terraform summary to.

Example `.drone.yml` with recommended branching flow using [drone-git-push](https://github.com/appleboy/drone-git-push) to manage the state:

```
pipeline:
  terraform_apply:
    image: justinbarrick/drone-terraform:2018.3.3
    root: terraform
    apply: "true"
    slack_url: SLACK_URL
    when:
      branch: master
      event: push

  terraform_push_state:
    image: appleboy/drone-git-push
    branch: master
    remote_name: origin
    commit_message: "Applying terraform state updates. [skip ci]"
    force: false
    commit: true
    secrets: [ GIT_PUSH_SSH_KEY ]
    when:
      branch: master
      event: push

  terraform_plan:
    image: justinbarrick/drone-terraform:2018.3.3
    root: terraform
    slack_url: SLACK_URL
    when:
      event: push

  terraform_push_plan:
    image: appleboy/drone-git-push
    branch: ${DRONE_BRANCH}
    remote_name: origin
    commit_message: "Terraform plan update. [skip ci]"
    force: false
    commit: true
    secrets: [ GIT_PUSH_SSH_KEY ]
    when:
      event: push

  slack:
    image: plugins/slack
    webhook: SLACK_URL
    channel: '#kubernetes'
    when:
      status: [success, failure]
      event: push
    template: >
      {{#success build.status}}
        Terraform build <{{build.link}}|#{{build.number}}> for <https://github.com/{{repo.owner}}/{{repo.name}}/tree/{{build.commit}}|{{repo.name}}#{{build.branch}}> by {{build.author}} succeeded!
      {{else}}
        Terraform build <{{build.link}}|#{{build.number}}> for <https://github.com/{{repo.owner}}/{{repo.name}}/tree/{{build.commit}}|{{repo.name}}#{{build.branch}}> by {{build.author}} failed.
      {{/success}}
```
