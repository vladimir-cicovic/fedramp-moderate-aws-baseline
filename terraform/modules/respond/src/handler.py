"""Automated containment for high-severity GuardDuty findings (IR-4, IR-4(1), IR-6).

AccessKey findings: deactivate the key and attach a deny-all policy to the user.
Instance findings: snapshot the volumes, then move the instance to the quarantine group.
Every action is reported to the alerts topic; DRY_RUN=true only reports.
"""
import json
import logging
import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
QUARANTINE_SG_BY_VPC = json.loads(os.environ.get("QUARANTINE_SG_BY_VPC", "{}"))
DENY_POLICY_NAME = "GuardDutyContainmentDenyAll"
DENY_POLICY = {
    "Version": "2012-10-17",
    "Statement": [{"Sid": "ContainmentDenyAll", "Effect": "Deny", "Action": "*", "Resource": "*"}],
}

iam = boto3.client("iam")
ec2 = boto3.client("ec2")
sns = boto3.client("sns")


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _tags(finding_id: str) -> list:
    return [
        {"Key": "ContainmentStatus", "Value": "Isolated"},
        {"Key": "ContainmentFinding", "Value": finding_id},
        {"Key": "ContainmentTime", "Value": _now()},
    ]


def contain_access_key(detail: dict, actions: list) -> None:
    key = detail["resource"].get("accessKeyDetails", {})
    user_name = key.get("userName")
    key_id = key.get("accessKeyId")
    user_type = key.get("userType")

    if user_type == "Root":
        actions.append("ROOT credentials involved: automation will not touch root; page the on-call now (IR-001 step 3b).")
        return
    if not user_name or not key_id or user_name == "GeneratedFindingUserName":
        actions.append(f"No real IAM user/key in finding (user={user_name}, key={key_id}); nothing to contain.")
        return

    if DRY_RUN:
        actions.append(f"DRY RUN: would deactivate access key {key_id} and attach {DENY_POLICY_NAME} to user {user_name}.")
        return

    try:
        iam.update_access_key(UserName=user_name, AccessKeyId=key_id, Status="Inactive")
        actions.append(f"Deactivated access key {key_id} of user {user_name}.")
    except ClientError as exc:
        actions.append(f"FAILED to deactivate key {key_id}: {exc.response['Error']['Code']}.")

    try:
        iam.put_user_policy(UserName=user_name, PolicyName=DENY_POLICY_NAME, PolicyDocument=json.dumps(DENY_POLICY))
        actions.append(f"Attached inline deny-all policy {DENY_POLICY_NAME} to user {user_name} (revokes active sessions).")
    except ClientError as exc:
        actions.append(f"FAILED to attach deny policy to {user_name}: {exc.response['Error']['Code']}.")

    try:
        iam.tag_user(UserName=user_name, Tags=_tags(detail["id"]))
    except ClientError as exc:
        actions.append(f"Could not tag user {user_name}: {exc.response['Error']['Code']}.")


def contain_instance(detail: dict, actions: list) -> None:
    inst = detail["resource"].get("instanceDetails", {})
    instance_id = inst.get("instanceId")
    if not instance_id or instance_id.startswith("i-99999999"):
        actions.append(f"No real EC2 instance in finding (instance={instance_id}); nothing to contain.")
        return

    try:
        desc = ec2.describe_instances(InstanceIds=[instance_id])["Reservations"][0]["Instances"][0]
    except (ClientError, IndexError, KeyError) as exc:
        actions.append(f"Instance {instance_id} not found or not readable: {exc}.")
        return

    vpc_id = desc.get("VpcId")
    quarantine_sg = QUARANTINE_SG_BY_VPC.get(vpc_id)
    volumes = [m["Ebs"]["VolumeId"] for m in desc.get("BlockDeviceMappings", []) if "Ebs" in m]

    if DRY_RUN:
        actions.append(f"DRY RUN: would snapshot {volumes} and move {instance_id} to quarantine SG {quarantine_sg} in {vpc_id}.")
        return

    for vol in volumes:
        try:
            snap = ec2.create_snapshot(
                VolumeId=vol,
                Description=f"Forensic snapshot for GuardDuty finding {detail['id']}",
                TagSpecifications=[{"ResourceType": "snapshot", "Tags": _tags(detail["id"])}],
            )
            actions.append(f"Snapshot {snap['SnapshotId']} created for volume {vol} (forensics, IR-4(4)).")
        except ClientError as exc:
            actions.append(f"FAILED snapshot of {vol}: {exc.response['Error']['Code']}.")

    if quarantine_sg:
        try:
            ec2.modify_instance_attribute(InstanceId=instance_id, Groups=[quarantine_sg])
            actions.append(f"Instance {instance_id} isolated: security groups replaced with {quarantine_sg}.")
        except ClientError as exc:
            actions.append(f"FAILED to isolate {instance_id}: {exc.response['Error']['Code']}.")
    else:
        actions.append(f"No quarantine security group known for VPC {vpc_id}; instance NOT isolated. Isolate manually (IR-002 step 4).")

    try:
        ec2.create_tags(Resources=[instance_id], Tags=_tags(detail["id"]))
    except ClientError as exc:
        actions.append(f"Could not tag instance {instance_id}: {exc.response['Error']['Code']}.")


def handler(event: dict, _context) -> dict:
    detail = event.get("detail", {})
    finding_id = detail.get("id", "unknown")
    finding_type = detail.get("type", "unknown")
    severity = detail.get("severity", 0)
    resource_type = detail.get("resource", {}).get("resourceType", "unknown")
    account = detail.get("accountId", "unknown")
    region = detail.get("region", "unknown")

    logger.info("finding %s type=%s severity=%s resource=%s dry_run=%s", finding_id, finding_type, severity, resource_type, DRY_RUN)
    actions: list = []

    if resource_type == "AccessKey":
        contain_access_key(detail, actions)
        runbook = "runbooks/IR-001-compromised-iam-credential.md"
    elif resource_type == "Instance":
        contain_instance(detail, actions)
        runbook = "runbooks/IR-002-guardduty-high-severity.md"
    else:
        actions.append(f"Resource type {resource_type} has no automated containment; manual triage.")
        runbook = "runbooks/IR-002-guardduty-high-severity.md"

    report = "\n".join(
        [
            f"[GuardDuty containment{' - DRY RUN' if DRY_RUN else ''}] {finding_type} (severity {severity}) in {account}/{region}",
            f"Finding: {finding_id}",
            f"Title: {detail.get('title', '')}",
            "Actions:",
            *[f"  - {a}" for a in actions],
            f"Next: {runbook}",
            f"Time: {_now()}",
        ]
    )
    logger.info(report)

    sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=f"GuardDuty containment: {finding_type[:80]}", Message=report)
    return {"finding": finding_id, "resource_type": resource_type, "dry_run": DRY_RUN, "actions": actions}
