variable "app_name" {
  default = "my-website-services"
}

variable "api_dist_path" {
  default = "../services/build/libs/"
}

variable "environment" {
  default = "prod"
}

variable "app_version" {
  default = "0.0.1"
}

provider "aws" {
  region = "us-east-2"
}

# create a zip of your deployment with terraform
data "archive_file" "api_dist_zip" {
  type        = "zip"
  source_file = "${path.root}/${var.api_dist_path}/${var.app_name}-${var.app_version}.jar"
  output_path = "${path.root}/${var.app_name}-${var.app_version}.zip"
}


resource "aws_s3_bucket" "dist_bucket" {
  bucket = "${var.app_name}-elb-dist"
}
resource "aws_s3_object" "object" {
  bucket = "${aws_s3_bucket.dist_bucket.id}"
  key    = "${var.environment}/${var.app_name}-${var.app_version}"
  source = "${path.root}/${var.app_name}-${var.app_version}.zip"
}


resource "aws_iam_instance_profile" "beanstalk_ec2" {
    name = "beanstalk-ec2-user"
    role = "${aws_iam_role.beanstalk_ec2.name}"
}
resource "aws_iam_role" "beanstalk_ec2" {
    name = "beanstalk-ec2-role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_policy_attachment" "beanstalk_ec2_worker" {
    name = "elastic-beanstalk-ec2-worker"
    roles = ["${aws_iam_role.beanstalk_ec2.id}"]
    policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}
resource "aws_iam_policy_attachment" "beanstalk_ec2_web" {
    name = "elastic-beanstalk-ec2-web"
    roles = ["${aws_iam_role.beanstalk_ec2.id}"]
    policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}
resource "aws_iam_policy_attachment" "beanstalk_ec2_container" {
    name = "elastic-beanstalk-ec2-container"
    roles = ["${aws_iam_role.beanstalk_ec2.id}"]
    policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}


resource "aws_elastic_beanstalk_application" "my-website-app" {
  name        = "${var.app_name}-elb-app"
  description = "My Website RESTful Services"
}

resource "aws_elastic_beanstalk_environment" "my-website-env" {
  name                = "${var.app_name}-elb-env"
  application         = aws_elastic_beanstalk_application.my-website-app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.2.4 running Corretto 17"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = "${aws_iam_instance_profile.beanstalk_ec2.name}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t2.micro"
  }
}

resource "aws_elastic_beanstalk_application_version" "version" {
  name        = "${var.app_version}"
  application = aws_elastic_beanstalk_application.my-website-app.name
  bucket      = aws_s3_bucket.dist_bucket.bucket
  key         = "${var.environment}/${var.app_name}-${var.app_version}"

  lifecycle {
    create_before_destroy = true
  }
}