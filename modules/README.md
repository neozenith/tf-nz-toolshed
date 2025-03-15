# TF Modules

<!--TOC-->

- [ TF Modules](#tf-modules)
  - [Overview](#overview)

<!--TOC-->

## Overview

- Each of these modules are standalone.
  - This is starting off as a monorepo architecture so all changes are visible across the platform in the one repo.
  - Over time these module folders could reasonably become their own repos. 
  - For now I am avoiding the complexity of the dependency management of securely referencing private repos to keep this project self-contained.


- Each module could be a collections of other modules to represent a _Pattern_.
  - [CDK Constructs](https://docs.aws.amazon.com/cdk/v2/guide/constructs.html) define 3 levels of _Constructs_.
    - L1: CloudFormation low level primitives
    - L2: _Curated Constructs_ like the [`terraform resource aws_s3_bucket`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
    - L3: _Patterns_ are much more complex compositions of the above _"lego bricks"_ which allow for more sophisticated patterns in your architecture to emerge.
      - Have a look the the [`aws-samples` Github Org and search for 'terraform'](https://github.com/orgs/aws-samples/repositories?language=&q=terraform&sort=&type=all). eg
        - https://github.com/aws-samples/aws-generative-ai-terraform-samples
        - https://github.com/aws-samples/serverless-voting-app-with-terraform