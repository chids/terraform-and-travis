:warning: This is **not intended** to be a fully working example :warning:

----

Dummy showcase for a _very_ basic Terraform + Travis setup that stores plans in S3 on PR's and applys on commits to `master`. The output from Terraform plan is posted as a comment on the PR after each build.

The [`bootstrap`](bootstrap/) folder contains a stand-alone Terraform setup that creates the resrouces for Terraform to use when run from Travis (buckets for state and plans, Dnynamodb table for locking).