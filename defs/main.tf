locals {
  salt_versions = "${sort(distinct(concat(list(var.salt_version), var.extra_salt_versions)))}"
  repo_prefix   = "${replace("${var.s3_endpoint}/${var.bucket_name}/${var.repo_prefix}", "/[/]$/", "")}"
}

data "null_data_source" "amzn" {
  count = "${length(local.salt_versions)}"

  inputs {
    name    = "salt-reposync-amzn"
    baseurl = "${local.repo_prefix}/amazon/latest/$basearch/archive/${local.salt_versions[count.index]}"
    gpgkey  = "${local.repo_prefix}/amazon/latest/$basearch/archive/${local.salt_versions[count.index]}/SALTSTACK-GPG-KEY.pub"
  }
}

data "null_data_source" "el6" {
  count = "${length(local.salt_versions)}"

  inputs {
    name    = "salt-reposync-el6"
    baseurl = "${local.repo_prefix}/redhat/6/$basearch/archive/${local.salt_versions[count.index]}"
    gpgkey  = "${local.repo_prefix}/redhat/6/$basearch/archive/${local.salt_versions[count.index]}/SALTSTACK-GPG-KEY.pub"
  }
}

data "null_data_source" "el7" {
  count = "${length(local.salt_versions)}"

  inputs {
    name    = "salt-reposync-el7"
    baseurl = "${local.repo_prefix}/redhat/7/$basearch/archive/${local.salt_versions[count.index]}"
    gpgkey  = "${local.repo_prefix}/redhat/7/$basearch/archive/${local.salt_versions[count.index]}/SALTSTACK-GPG-KEY.pub"
  }
}

data "template_file" "amzn" {
  count = "${length(local.salt_versions)}"

  template = "${file("${path.module}/yum.repo")}"

  vars {
    name    = "${lookup(data.null_data_source.amzn.*.outputs[count.index], "name")}"
    baseurl = "${lookup(data.null_data_source.amzn.*.outputs[count.index], "baseurl")}"
    gpgkey  = "${lookup(data.null_data_source.amzn.*.outputs[count.index], "gpgkey")}"
  }
}

data "template_file" "el6" {
  count = "${length(local.salt_versions)}"

  template = "${file("${path.module}/yum.repo")}"

  vars {
    name    = "${lookup(data.null_data_source.el6.*.outputs[count.index], "name")}"
    baseurl = "${lookup(data.null_data_source.el6.*.outputs[count.index], "baseurl")}"
    gpgkey  = "${lookup(data.null_data_source.el6.*.outputs[count.index], "gpgkey")}"
  }
}

data "template_file" "el7" {
  count = "${length(local.salt_versions)}"

  template = "${file("${path.module}/yum.repo")}"

  vars {
    name    = "${lookup(data.null_data_source.el7.*.outputs[count.index], "name")}"
    baseurl = "${lookup(data.null_data_source.el7.*.outputs[count.index], "baseurl")}"
    gpgkey  = "${lookup(data.null_data_source.el7.*.outputs[count.index], "gpgkey")}"
  }
}

resource "local_file" "amzn" {
  count = "${length(local.salt_versions)}"

  content  = "${data.template_file.amzn.*.rendered[count.index]}"
  filename = "${var.cache_dir}/${local.salt_versions[count.index]}/salt-reposync-amzn}"
}

resource "local_file" "el6" {
  count = "${length(local.salt_versions)}"

  content  = "${data.template_file.el6.*.rendered[count.index]}"
  filename = "${var.cache_dir}/${local.salt_versions[count.index]}/salt-reposync-el6}"
}

resource "local_file" "el7" {
  count = "${length(local.salt_versions)}"

  content  = "${data.template_file.el7.*.rendered[count.index]}"
  filename = "${var.cache_dir}/${local.salt_versions[count.index]}/salt-reposync-el7}"
}

resource "local_file" "amzn_default" {
  content  = "${data.template_file.amzn.*.rendered[index(local.salt_versions, var.salt_version)]}"
  filename = "${var.cache_dir}/salt-reposync-amzn"
}

resource "local_file" "el6_default" {
  content  = "${data.template_file.el6.*.rendered[index(local.salt_versions, var.salt_version)]}"
  filename = "${var.cache_dir}/salt-reposync-el6"
}

resource "local_file" "el7_default" {
  content  = "${data.template_file.el7.*.rendered[index(local.salt_versions, var.salt_version)]}"
  filename = "${var.cache_dir}/salt-reposync-el7"
}

locals {
  s3_command = [
    "aws s3 sync --delete",
    "${var.cache_dir}",
    "s3://${var.bucket_name}/${replace(var.yum_prefix, "/[/]$/", "")}",
  ]

  s3_command_destroy = [
    "aws s3 rm --recursive",
    "s3://${var.bucket_name}/${replace(var.yum_prefix, "/[/]$/", "")}",
  ]
}

resource "null_resource" "push" {
  provisioner "local-exec" {
    command = "${join(" ", local.s3_command)}"
  }

  provisioner "local-exec" {
    command = "${join(" ", local.s3_command_destroy)}"
    when    = "destroy"
  }

  triggers {
    salt_versions = "${join(",", local.salt_versions)}"
    s3_command    = "${join(" ", local.s3_command)}"
  }

  depends_on = [
    "local_file.amzn",
    "local_file.el6",
    "local_file.el7",
    "local_file.amzn_default",
    "local_file.el6_default",
    "local_file.el7_default",
  ]
}