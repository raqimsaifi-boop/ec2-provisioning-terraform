import json
import os
import uuid
import boto3
from datetime import datetime

s3 = boto3.client("s3")
ssm = boto3.client("ssm")
codepipeline = boto3.client("codepipeline")

BUCKET = os.environ.get("REQUESTBUCKET", "tfvars-request-bucket")
PIPELINENAME = os.environ.get("PIPELINENAME", "ec2-provisioning-pipeline")
DEFAULTPROFILENAME = os.environ.get("NETWORKPROFILENAME", "ec2")

def normalizeenvironment(env):
    m = {
        "prod": "Production", "production": "Production",
        "dev": "Dev", "test": "Test",
        "uat": "UAT", "staging": "Staging",
        "training": "Training"
    }
    return m.get(env.strip().lower(), env)

def handler(event, context):
    """
    Expected event (from SNOW or test):
    {
      "region": "ap-south-1",
      "environment": "Production",
      "instances": [{
        "name": "APP-PROD-01",
        "size": "large",
        "tags": {…},
        "ebsrootsizegb": 50,
        "ebsroottype": "gp3",
        "ebsrootiops": 3000
      }],
      "networkprofilename": "ec2"  # optional
    }
    """
    try:
        # Allow API Gateway proxy where body is a string
        payload = event.get("body", event)
        if isinstance(payload, str):
            payload = json.loads(payload)

        region = payload["region"]
        environment = normalizeenvironment(payload["environment"])
        networkprofilename = payload.get("networkprofilename", DEFAULTPROFILENAME)

        # Optional: fetch the profile to validate it exists (helps fail fast)
        profilekey = f"/provisioning/{region}/{environment}/{networkprofilename}"
        ssm.getparameter(Name=profilekey)

        # Build tfvars content
        tfvars = {
            "region": region,
            "environment": environment,
            "networkprofilename": networkprofilename,
            "instances": payload["instances"]
        }

        # Write to S3
        reqid = str(uuid.uuid4())
        key = f"provisioning/requests/{reqid}.auto.tfvars.json"
        s3.putobject(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps(tfvars, indent=2),
            ContentType="application/json"
        )

        # Trigger pipeline (pass S3 key as a user parameter via artifact or variable)
        # If your pipeline reads from S3, ensure the Source stage is configured.
        try:
            codepipeline.startpipelineexecution(name=PIPELINENAME)
            pipelinestarted = True
        except Exception as e:
            pipelinestarted = False

        # Return the tfvars (useful for testing locally without SNOW)
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "requestId": reqid,
                "s3Key": key,
                "pipelineStarted": pipelinestarted,
                "tfvars": tfvars
            }, indent=2)
        }

    except Exception as e:
               return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)}, indent=2)
               }
