locals {
  common_tags = {
    Env       = "${var.project_env}"
    Namespace = "${var.namespace}"
  }

  temp_file_assumerole = "${var.temp_file_assumerole == "" ? "AssumeRoleService.json.tpl" : var.temp_file_assumerole }"
  temp_file_policy     = "${var.temp_file_policy == "" ? "Policy.json.tpl" : var.temp_file_policy }"
  name                 = "${var.namespace == "" ? "" : "${lower(var.namespace)}-"}${lower(var.project_env_short)}-${lower(var.name)}"
}

data "template_file" "assume_role" {
  template = "${file(local.temp_file_assumerole)}"
  vars {
    identifiers = "${jsonencode(var.identifiers)}"
  }
}

data "template_file" "inline" {
  count    = "${var.inline_policy ? 1 : 0}"
  template = "${file(local.temp_file_policy)}"
}

resource "aws_iam_role" "this" {
  name               = "${local.name}"
  assume_role_policy = "${data.template_file.assume_role.rendered}"
  tags               = "${merge(var.tags, local.common_tags)}"
}

resource "aws_iam_role_policy_attachment" "aws" {
  count      = "${length(var.aws_policies)}"
  role       = "${aws_iam_role.this.name}"
  policy_arn = "arn:aws:iam::aws:policy/${element(var.aws_policies,count.index)}"
}

resource "aws_iam_role_policy_attachment" "service_roles" {
  count      = "${length(var.service_roles)}"
  role       = "${aws_iam_role.this.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/${element(var.service_roles,count.index)}"
}

resource "aws_iam_role_policy_attachment" "aws_service_roles" {
  count      = "${length(var.aws_service_roles)}"
  role       = "${aws_iam_role.this.name}"
  policy_arn = "arn:aws:iam::aws:policy/aws-service-role/${element(var.aws_service_roles,count.index)}"
}

resource "aws_iam_role_policy" "inline" {
  count  = "${var.inline_policy ? 1 : 0}"
  name   = "${local.name}"
  role   = "${aws_iam_role.this.id}"
  policy = "${data.template_file.inline.rendered}"
}

resource "aws_iam_instance_profile" "ec2" {
  count = "${contains(var.identifiers, "ec2.amazonaws.com") ? 1 : 0}"
  name  = "${local.name}"
  role  = "${aws_iam_role.this.name}"
}
