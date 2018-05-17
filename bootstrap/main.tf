terraform {
  required_version = "~> 0.11"
}

variable "AWS_REGION" {
  type = "string"
  default = "eu-central-1"
}

variable "GH_STATUS_TOKEN" {
  type = "string"
}

locals {
  project = "some-reasonable-name"
}

provider "aws" {
  region  = "${var.AWS_REGION}"
  version = "~> 1.11"
}

data "template_file" "backend-conf" {
  template = "${file("backend-conf.txt")}"
  vars {
    lock    = "${aws_dynamodb_table.lock.id}"
    region  = "${var.AWS_REGION}"
    bucket  = "${aws_s3_bucket.state.id}"
    project = "${local.project}"
  }
}

resource "local_file" "file" {
  content  = "${data.template_file.backend-conf.rendered}"
  filename = "${path.root}/../infrastructure/backend.conf"
}

resource "null_resource" "travis-aws-region" {
  provisioner "local-exec" {
    command = "cd .. && travis env set AWS_REGION ${var.AWS_REGION} --public"
  }
  triggers {
    region = "${var.AWS_REGION}"
  }
}

resource "null_resource" "travis-aws-key" {
  provisioner "local-exec" {
    command = "cd .. && travis env set AWS_ACCESS_KEY_ID ${aws_iam_access_key.terraform.id} --public"
  }
  triggers {
    iam_key = "${aws_iam_access_key.terraform.id}"
  }
  depends_on = [ "null_resource.travis-aws-region" ]
}

resource "null_resource" "travis-aws-secret" {
  provisioner "local-exec" {
    command = "cd .. && travis env set AWS_SECRET_ACCESS_KEY ${aws_iam_access_key.terraform.secret} --private"
  }
  triggers {
    iam_key = "${aws_iam_access_key.terraform.id}"
  }
  depends_on = [ "null_resource.travis-aws-key" ]
}

resource "null_resource" "travis-s3-plans" {
  provisioner "local-exec" {
    command = "cd .. && travis env set PLAN_BUCKET ${aws_s3_bucket.plans.id} --public"
  }
  triggers {
    bucket = "${aws_s3_bucket.plans.id}"
  }
  depends_on = [ "null_resource.travis-aws-secret" ]
}

resource "null_resource" "travis-gh-status-token" {
  provisioner "local-exec" {
    command = "cd .. && travis env set GH_STATUS_TOKEN ${var.GH_STATUS_TOKEN} --private"
  }
  triggers {
    token = "${sha1("${var.GH_STATUS_TOKEN}")}"
  }
  depends_on = [ "null_resource.travis-s3-plans" ]
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "state" {
  bucket = "${local.project}-state"
  acl    = "private"
  versioning {
    enabled = true
  }
  lifecycle_rule {
    id      = "expire-old-version"
    enabled = true
    noncurrent_version_expiration {
      days = 90
    }
  }
}

data "aws_iam_policy_document" "s3-state" {
  statement {
    effect = "Allow"
    actions = [ "s3:ListBucket" ]
    resources = [ "${aws_s3_bucket.state.arn}" ]
  }
  statement {
    effect = "Allow"
    actions = [ "s3:GetObject", "s3:PutObject", "s3:PutObjectAcl" ]
    resources = [ "${aws_s3_bucket.state.arn}/*" ]
  }
}

resource "aws_iam_user_policy_attachment" "s3-state" {
    user       = "${aws_iam_user.terraform.name}"
    policy_arn = "${aws_iam_policy.s3-state.arn}"
}

resource "aws_iam_policy" "s3-state" {
  name   = "${local.project}-s3-state"
  path   = "/terraform/"
  policy = "${data.aws_iam_policy_document.s3-state.json}"
}


resource "aws_s3_bucket" "plans" {
  bucket = "${local.project}-s3-plans"
  acl    = "private"
  versioning {
    enabled = false
  }
  lifecycle_rule {
    id      = "auto-expire"
    enabled = true
    expiration {
      days = 14
    }
  }
}

data "aws_iam_policy_document" "s3-plans" {
  statement {
    effect = "Allow"
    actions = [ "s3:ListBucket", "s3:GetBucketLocation" ]
    resources = [ "${aws_s3_bucket.plans.arn}" ]
  }
  statement {
    effect = "Allow"
    actions = [ "s3:GetObject", "s3:PutObject", "s3:PutObjectAcl", "s3:DeleteObject" ]
    resources = [ "${aws_s3_bucket.plans.arn}/*" ]
  }
}

resource "aws_iam_user_policy_attachment" "s3-plans" {
    user       = "${aws_iam_user.terraform.name}"
    policy_arn = "${aws_iam_policy.s3-plans.arn}"
}

resource "aws_iam_policy" "s3-plans" {
  name   = "${local.project}-s3-plans"
  path   = "/terraform/"
  policy = "${data.aws_iam_policy_document.s3-plans.json}"
}

resource "aws_dynamodb_table" "lock" {
  name           = "${local.project}-lock"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_iam_user" "terraform" {
  name = "${local.project}"
  path = "/terraform/"
}

resource "aws_iam_access_key" "terraform" {
  user = "${aws_iam_user.terraform.name}"
}

data "aws_iam_policy_document" "dynamodb" {
  statement {
    effect = "Allow"
    actions = [ "dynamodb:DeleteItem", "dynamodb:GetItem", "dynamodb:PutItem" ]
    resources = [ "${aws_dynamodb_table.lock.arn}" ]
  }
}

resource "aws_iam_policy" "dynamodb" {
  name   = "${local.project}-dynamodb"
  path   = "/terraform/"
  policy = "${data.aws_iam_policy_document.dynamodb.json}"
}

resource "aws_iam_user_policy_attachment" "dynamodb" {
    user       = "${aws_iam_user.terraform.name}"
    policy_arn = "${aws_iam_policy.dynamodb.arn}"
}