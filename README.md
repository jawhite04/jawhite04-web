# jawhite04.com
Frontend for jawhite04.com.

## Purpose
- To practice deploying web content to AWS
    - static file(s) via S3 + Cloudfront
    - servers via EC2/Fargate
    - AWS Beanstalk
- To provide a frontend for backend development
    - API development for SPA-like content
    - explore MVC, SSR, HTMX

## Prereqs
- https://github.com/jawhite04/aws-infrastructure

To invalidate cloudfront distribution:

```bash
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[0].Id" --output text)

aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths '/*'
```
