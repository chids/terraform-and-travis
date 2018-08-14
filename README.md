:warning: This is **not intended** to be a fully working example :warning:

----

Dummy showcase for a _very_ basic Terraform + Travis setup:
* The output from Terraform `plan` is posted as a comment on the PR after each build
* The plan file is stored in S3 as part of the PR build
* The stored plan is applied when the PR is merged to `master`

The [`bootstrap`](bootstrap/) folder contains a stand-alone Terraform setup that creates the resrouces for Terraform to use when run from Travis (S3 buckets for state and plans and a DynamoDB table for locking).
