#!/bin/bash

# Script to find and clean up stale AWS resources left behind by failed OCP cluster installs.
# By default runs in dry-run mode (report only). Use --delete to actually remove resources.
#
# Usage: ./cleanup-aws-resources.sh [--delete] [--region <aws-region>]
#
# IMPORTANT: This script preserves Route53 hosted zones and their records by default.
# Use --delete-hosted-zones to also remove cluster-specific sub-hosted zones (e.g.
# "clustername.apicurio-testing.org") but NEVER the top-level domain zone.

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

# Source secrets.env if it exists
if [[ -f "$BASE_DIR/secrets.env" ]]; then
    echo "Sourcing environment variables from secrets.env..."
    source "$BASE_DIR/secrets.env"
fi

# --- Configuration ---
DELETE_MODE="false"
DELETE_HOSTED_ZONES="false"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
BASE_DOMAIN="apicurio-testing.org"

# Tag used to identify OCP installer resources
TAG_KEY="apicurio/FromOcpInstaller"
TAG_VALUE="true"

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --delete)
            DELETE_MODE="true"
            shift
            ;;
        --delete-hosted-zones)
            DELETE_HOSTED_ZONES="true"
            shift
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--delete] [--delete-hosted-zones] [--region <aws-region>]"
            echo ""
            echo "Options:"
            echo "  --delete               Actually delete resources (default: dry-run/report only)"
            echo "  --delete-hosted-zones  Also delete cluster-specific Route53 sub-hosted zones"
            echo "  --region <region>      AWS region (default: us-east-1)"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

export AWS_DEFAULT_REGION="$REGION"

# --- Helpers ---
TOTAL_FOUND=0
TOTAL_DELETED=0

# Prints a section header
section() {
    echo ""
    echo "=========================================="
    echo "  $1"
    echo "=========================================="
}

# Logs a found resource and increments counter
found() {
    echo "  [FOUND] $1"
    TOTAL_FOUND=$((TOTAL_FOUND + 1))
}

# Attempts to delete a resource (or reports dry-run)
do_delete() {
    local label="$1"
    shift
    if [[ "$DELETE_MODE" == "true" ]]; then
        echo "  [DELETE] $label"
        if "$@" 2>&1 | sed 's/^/    /'; then
            TOTAL_DELETED=$((TOTAL_DELETED + 1))
        else
            error "  Failed to delete: $label"
        fi
    else
        echo "  [DRY-RUN] Would delete: $label"
    fi
}

# --- EC2 Instances ---
delete_instances() {
    section "EC2 Instances"

    local instances
    instances=$(aws ec2 describe-instances --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
        --query 'Reservations[*].Instances[*].[InstanceId, Tags[?Key==`Name`].Value | [0], Tags[?Key==`apicurio/cluster`].Value | [0]]' \
        --output text 2>/dev/null)

    if [[ -z "$instances" ]]; then
        echo "  No instances found."
        return
    fi

    while IFS=$'\t' read -r instance_id name cluster; do
        found "Instance $instance_id ($name) [cluster: $cluster]"
        do_delete "Instance $instance_id ($name)" \
            aws ec2 terminate-instances --region "$REGION" --instance-ids "$instance_id"
    done <<< "$instances"

    if [[ "$DELETE_MODE" == "true" && -n "$instances" ]]; then
        local instance_ids
        instance_ids=$(echo "$instances" | awk '{print $1}' | tr '\n' ' ')
        echo "  Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --region "$REGION" --instance-ids $instance_ids 2>/dev/null || true
        echo "  Instances terminated."
    fi
}

# --- Load Balancers (ELBv2 / NLB / ALB) ---
delete_load_balancers() {
    section "Load Balancers (ELBv2)"

    local lbs
    lbs=$(aws elbv2 describe-load-balancers --region "$REGION" \
        --query 'LoadBalancers[*].[LoadBalancerArn, LoadBalancerName]' --output text 2>/dev/null)

    if [[ -z "$lbs" ]]; then
        echo "  No load balancers found."
        return
    fi

    while IFS=$'\t' read -r arn name; do
        # Check if this LB has the OCP tag
        local has_tag
        has_tag=$(aws elbv2 describe-tags --region "$REGION" --resource-arns "$arn" \
            --query "TagDescriptions[*].Tags[?Key=='${TAG_KEY}' && Value=='${TAG_VALUE}'] | [] | length(@)" \
            --output text 2>/dev/null)
        if [[ "$has_tag" -gt 0 ]]; then
            found "Load Balancer $name ($arn)"
            do_delete "Load Balancer $name" \
                aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn"
        fi
    done <<< "$lbs"

    # Also check classic ELBs
    local classic_lbs
    classic_lbs=$(aws elb describe-load-balancers --region "$REGION" \
        --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text 2>/dev/null)

    if [[ -n "$classic_lbs" ]]; then
        for lb_name in $classic_lbs; do
            local has_tag
            has_tag=$(aws elb describe-tags --region "$REGION" --load-balancer-names "$lb_name" \
                --query "TagDescriptions[*].Tags[?Key=='${TAG_KEY}' && Value=='${TAG_VALUE}'] | [] | length(@)" \
                --output text 2>/dev/null)
            if [[ "$has_tag" -gt 0 ]]; then
                found "Classic Load Balancer $lb_name"
                do_delete "Classic Load Balancer $lb_name" \
                    aws elb delete-load-balancer --region "$REGION" --load-balancer-name "$lb_name"
            fi
        done
    fi

    # Delete target groups associated with deleted LBs
    local tgs
    tgs=$(aws elbv2 describe-target-groups --region "$REGION" \
        --query 'TargetGroups[?length(LoadBalancerArns)==`0`].[TargetGroupArn, TargetGroupName]' \
        --output text 2>/dev/null)

    if [[ -n "$tgs" ]]; then
        while IFS=$'\t' read -r tg_arn tg_name; do
            local has_tag
            has_tag=$(aws elbv2 describe-tags --region "$REGION" --resource-arns "$tg_arn" \
                --query "TagDescriptions[*].Tags[?Key=='${TAG_KEY}' && Value=='${TAG_VALUE}'] | [] | length(@)" \
                --output text 2>/dev/null)
            if [[ "$has_tag" -gt 0 ]]; then
                found "Orphaned Target Group $tg_name"
                do_delete "Target Group $tg_name" \
                    aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$tg_arn"
            fi
        done <<< "$tgs"
    fi
}

# --- NAT Gateways ---
delete_nat_gateways() {
    section "NAT Gateways"

    local nats
    nats=$(aws ec2 describe-nat-gateways --region "$REGION" \
        --filter "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" "Name=state,Values=available,pending,failed" \
        --query 'NatGateways[*].[NatGatewayId, Tags[?Key==`Name`].Value | [0], State]' \
        --output text 2>/dev/null)

    if [[ -z "$nats" ]]; then
        echo "  No NAT gateways found."
        return
    fi

    local nat_ids=()
    while IFS=$'\t' read -r nat_id name state; do
        found "NAT Gateway $nat_id ($name) [state: $state]"
        do_delete "NAT Gateway $nat_id ($name)" \
            aws ec2 delete-nat-gateway --region "$REGION" --nat-gateway-id "$nat_id"
        nat_ids+=("$nat_id")
    done <<< "$nats"

    if [[ "$DELETE_MODE" == "true" && ${#nat_ids[@]} -gt 0 ]]; then
        echo "  Waiting for NAT gateways to be deleted (this can take a few minutes)..."
        for nat_id in "${nat_ids[@]}"; do
            aws ec2 wait nat-gateway-deleted --region "$REGION" --nat-gateway-ids "$nat_id" 2>/dev/null || true
        done
        echo "  NAT gateways deleted."
    fi
}

# --- Elastic IPs ---
delete_elastic_ips() {
    section "Elastic IPs"

    local eips
    eips=$(aws ec2 describe-addresses --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'Addresses[*].[AllocationId, PublicIp, AssociationId, Tags[?Key==`Name`].Value | [0], Tags[?Key==`apicurio/cluster`].Value | [0]]' \
        --output text 2>/dev/null)

    if [[ -z "$eips" ]]; then
        echo "  No Elastic IPs found."
        return
    fi

    while IFS=$'\t' read -r alloc_id public_ip assoc_id name cluster; do
        found "EIP $public_ip ($alloc_id) ($name) [cluster: $cluster]"
        # Disassociate first if associated
        if [[ "$assoc_id" != "None" && -n "$assoc_id" ]]; then
            do_delete "Disassociate EIP $public_ip" \
                aws ec2 disassociate-address --region "$REGION" --association-id "$assoc_id"
        fi
        do_delete "Release EIP $public_ip ($alloc_id)" \
            aws ec2 release-address --region "$REGION" --allocation-id "$alloc_id"
    done <<< "$eips"
}

# --- Internet Gateways ---
delete_internet_gateways() {
    section "Internet Gateways"

    local igws
    igws=$(aws ec2 describe-internet-gateways --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'InternetGateways[*].[InternetGatewayId, Attachments[0].VpcId, Tags[?Key==`Name`].Value | [0]]' \
        --output text 2>/dev/null)

    if [[ -z "$igws" ]]; then
        echo "  No internet gateways found."
        return
    fi

    while IFS=$'\t' read -r igw_id vpc_id name; do
        found "Internet Gateway $igw_id ($name) [vpc: $vpc_id]"
        if [[ "$vpc_id" != "None" && -n "$vpc_id" ]]; then
            do_delete "Detach IGW $igw_id from VPC $vpc_id" \
                aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$igw_id" --vpc-id "$vpc_id"
        fi
        do_delete "Delete IGW $igw_id ($name)" \
            aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$igw_id"
    done <<< "$igws"
}

# --- Subnets ---
delete_subnets() {
    section "Subnets"

    local subnets
    subnets=$(aws ec2 describe-subnets --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'Subnets[*].[SubnetId, VpcId, CidrBlock, Tags[?Key==`Name`].Value | [0]]' \
        --output text 2>/dev/null)

    if [[ -z "$subnets" ]]; then
        echo "  No subnets found."
        return
    fi

    while IFS=$'\t' read -r subnet_id vpc_id cidr name; do
        found "Subnet $subnet_id ($name) [$cidr in $vpc_id]"
        do_delete "Subnet $subnet_id ($name)" \
            aws ec2 delete-subnet --region "$REGION" --subnet-id "$subnet_id"
    done <<< "$subnets"
}

# --- Security Groups ---
delete_security_groups() {
    section "Security Groups"

    local sgs
    sgs=$(aws ec2 describe-security-groups --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'SecurityGroups[*].[GroupId, GroupName, VpcId]' \
        --output text 2>/dev/null)

    if [[ -z "$sgs" ]]; then
        echo "  No security groups found."
        return
    fi

    # First pass: remove all ingress/egress rules that reference other SGs in this set
    # This avoids dependency errors when deleting
    local sg_ids=()
    while IFS=$'\t' read -r sg_id sg_name vpc_id; do
        sg_ids+=("$sg_id")
    done <<< "$sgs"

    if [[ "$DELETE_MODE" == "true" ]]; then
        echo "  Removing cross-references between security groups..."
        for sg_id in "${sg_ids[@]}"; do
            # Remove all ingress rules
            local ingress_rules
            ingress_rules=$(aws ec2 describe-security-groups --region "$REGION" \
                --group-ids "$sg_id" \
                --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null)
            if [[ "$ingress_rules" != "[]" && -n "$ingress_rules" ]]; then
                aws ec2 revoke-security-group-ingress --region "$REGION" \
                    --group-id "$sg_id" --ip-permissions "$ingress_rules" 2>/dev/null || true
            fi

            # Remove all egress rules
            local egress_rules
            egress_rules=$(aws ec2 describe-security-groups --region "$REGION" \
                --group-ids "$sg_id" \
                --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null)
            if [[ "$egress_rules" != "[]" && -n "$egress_rules" ]]; then
                aws ec2 revoke-security-group-egress --region "$REGION" \
                    --group-id "$sg_id" --ip-permissions "$egress_rules" 2>/dev/null || true
            fi
        done
    fi

    # Second pass: delete the security groups
    while IFS=$'\t' read -r sg_id sg_name vpc_id; do
        found "Security Group $sg_id ($sg_name) [vpc: $vpc_id]"
        do_delete "Security Group $sg_id ($sg_name)" \
            aws ec2 delete-security-group --region "$REGION" --group-id "$sg_id"
    done <<< "$sgs"
}

# --- Route Tables ---
delete_route_tables() {
    section "Route Tables (custom)"

    local rts
    rts=$(aws ec2 describe-route-tables --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'RouteTables[*].[RouteTableId, VpcId, Tags[?Key==`Name`].Value | [0], Associations[?Main==`true`] | length(@)]' \
        --output text 2>/dev/null)

    if [[ -z "$rts" ]]; then
        echo "  No custom route tables found."
        return
    fi

    while IFS=$'\t' read -r rt_id vpc_id name is_main; do
        # Skip main route tables - they get deleted with the VPC
        if [[ "$is_main" -gt 0 ]]; then
            echo "  [SKIP] Main route table $rt_id ($name) - deleted with VPC"
            continue
        fi

        found "Route Table $rt_id ($name) [vpc: $vpc_id]"

        # Disassociate any subnet associations first
        if [[ "$DELETE_MODE" == "true" ]]; then
            local assoc_ids
            assoc_ids=$(aws ec2 describe-route-tables --region "$REGION" \
                --route-table-ids "$rt_id" \
                --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' \
                --output text 2>/dev/null)
            for assoc_id in $assoc_ids; do
                if [[ -n "$assoc_id" && "$assoc_id" != "None" ]]; then
                    aws ec2 disassociate-route-table --region "$REGION" \
                        --association-id "$assoc_id" 2>/dev/null || true
                fi
            done
        fi

        do_delete "Route Table $rt_id ($name)" \
            aws ec2 delete-route-table --region "$REGION" --route-table-id "$rt_id"
    done <<< "$rts"
}

# --- VPC Endpoints ---
delete_vpc_endpoints() {
    section "VPC Endpoints"

    local endpoints
    endpoints=$(aws ec2 describe-vpc-endpoints --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'VpcEndpoints[*].[VpcEndpointId, VpcId, ServiceName]' \
        --output text 2>/dev/null)

    if [[ -z "$endpoints" ]]; then
        echo "  No VPC endpoints found."
        return
    fi

    while IFS=$'\t' read -r endpoint_id vpc_id service_name; do
        found "VPC Endpoint $endpoint_id ($service_name) [vpc: $vpc_id]"
        do_delete "VPC Endpoint $endpoint_id" \
            aws ec2 delete-vpc-endpoints --region "$REGION" --vpc-endpoint-ids "$endpoint_id"
    done <<< "$endpoints"
}

# --- VPCs ---
delete_vpcs() {
    section "VPCs"

    local vpcs
    vpcs=$(aws ec2 describe-vpcs --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'Vpcs[*].[VpcId, CidrBlock, Tags[?Key==`Name`].Value | [0], Tags[?Key==`apicurio/cluster`].Value | [0]]' \
        --output text 2>/dev/null)

    if [[ -z "$vpcs" ]]; then
        echo "  No VPCs found."
        return
    fi

    while IFS=$'\t' read -r vpc_id cidr name cluster; do
        found "VPC $vpc_id ($name) [$cidr] [cluster: $cluster]"
        do_delete "VPC $vpc_id ($name)" \
            aws ec2 delete-vpc --region "$REGION" --vpc-id "$vpc_id"
    done <<< "$vpcs"
}

# --- S3 Buckets (image registries) ---
delete_s3_buckets() {
    section "S3 Buckets (image registries)"

    local buckets
    buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text 2>/dev/null)

    if [[ -z "$buckets" ]]; then
        echo "  No S3 buckets found."
        return
    fi

    local found_any="false"
    for bucket in $buckets; do
        # OCP image registry buckets follow the pattern: <cluster-infra-id>-image-registry-<region>-*
        if [[ "$bucket" == *"-image-registry-"* ]]; then
            local has_tag
            has_tag=$(aws s3api get-bucket-tagging --bucket "$bucket" \
                --query "TagSet[?Key=='${TAG_KEY}' && Value=='${TAG_VALUE}'] | length(@)" \
                --output text 2>/dev/null || echo "0")
            if [[ "$has_tag" -gt 0 ]]; then
                found "S3 Bucket $bucket"
                found_any="true"
                if [[ "$DELETE_MODE" == "true" ]]; then
                    echo "  [DELETE] Emptying bucket $bucket..."
                    aws s3 rm "s3://$bucket" --recursive 2>&1 | tail -1 | sed 's/^/    /' || true
                    do_delete "S3 Bucket $bucket" \
                        aws s3api delete-bucket --bucket "$bucket"
                fi
            fi
        fi
    done

    if [[ "$found_any" == "false" ]]; then
        echo "  No OCP image registry buckets found."
    fi
}

# --- IAM Roles and Instance Profiles ---
delete_iam_resources() {
    section "IAM Roles and Instance Profiles"

    # Find instance profiles with OCP cluster naming pattern
    local profiles
    profiles=$(aws iam list-instance-profiles \
        --query 'InstanceProfiles[?contains(InstanceProfileName, `-master-profile`) || contains(InstanceProfileName, `-worker-profile`)].{Name:InstanceProfileName,Roles:Roles[*].RoleName}' \
        --output json 2>/dev/null)

    local profile_count
    profile_count=$(echo "$profiles" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [[ "$profile_count" -eq 0 ]]; then
        echo "  No OCP instance profiles found."
        return
    fi

    echo "$profiles" | python3 -c "
import json, sys
profiles = json.load(sys.stdin)
for p in profiles:
    roles = ','.join(p.get('Roles', []))
    print(f\"{p['Name']}\t{roles}\")
" | while IFS=$'\t' read -r profile_name role_names; do
        found "Instance Profile $profile_name (roles: $role_names)"

        if [[ "$DELETE_MODE" == "true" ]]; then
            # Remove roles from instance profile first
            for role_name in $(echo "$role_names" | tr ',' ' '); do
                if [[ -n "$role_name" ]]; then
                    echo "  [DELETE] Removing role $role_name from profile $profile_name"
                    aws iam remove-role-from-instance-profile \
                        --instance-profile-name "$profile_name" \
                        --role-name "$role_name" 2>/dev/null || true
                fi
            done
            do_delete "Instance Profile $profile_name" \
                aws iam delete-instance-profile --instance-profile-name "$profile_name"
        fi
    done

    # Find and delete IAM roles with OCP cluster naming pattern
    local roles
    roles=$(aws iam list-roles \
        --query 'Roles[?contains(RoleName, `-master-role`) || contains(RoleName, `-worker-role`)].RoleName' \
        --output text 2>/dev/null)

    if [[ -z "$roles" ]]; then
        return
    fi

    for role_name in $roles; do
        found "IAM Role $role_name"

        if [[ "$DELETE_MODE" == "true" ]]; then
            # Detach all managed policies
            local policies
            policies=$(aws iam list-attached-role-policies --role-name "$role_name" \
                --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null)
            for policy_arn in $policies; do
                if [[ -n "$policy_arn" ]]; then
                    aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" 2>/dev/null || true
                fi
            done

            # Delete inline policies
            local inline_policies
            inline_policies=$(aws iam list-role-policies --role-name "$role_name" \
                --query 'PolicyNames' --output text 2>/dev/null)
            for policy_name in $inline_policies; do
                if [[ -n "$policy_name" ]]; then
                    aws iam delete-role-policy --role-name "$role_name" --policy-name "$policy_name" 2>/dev/null || true
                fi
            done

            do_delete "IAM Role $role_name" \
                aws iam delete-role --role-name "$role_name"
        fi
    done
}

# --- Route53 Hosted Zones (cluster sub-zones only) ---
delete_hosted_zones() {
    section "Route53 Hosted Zones (cluster sub-zones)"

    local zones
    zones=$(aws route53 list-hosted-zones \
        --query 'HostedZones[*].[Id, Name]' --output text 2>/dev/null)

    if [[ -z "$zones" ]]; then
        echo "  No hosted zones found."
        return
    fi

    while IFS=$'\t' read -r zone_id zone_name; do
        # Skip the top-level domain zone
        if [[ "$zone_name" == "${BASE_DOMAIN}." ]]; then
            echo "  [SKIP] Top-level domain zone: $zone_name (preserved)"
            continue
        fi

        # Only target sub-zones of our base domain
        if [[ "$zone_name" == *".${BASE_DOMAIN}." ]]; then
            found "Hosted Zone $zone_id ($zone_name)"

            if [[ "$DELETE_HOSTED_ZONES" != "true" ]]; then
                echo "  [SKIP] Use --delete-hosted-zones to remove cluster sub-zones"
                continue
            fi

            if [[ "$DELETE_MODE" == "true" ]]; then
                # Must delete all non-NS/SOA records first
                local record_sets
                record_sets=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" \
                    --query "ResourceRecordSets[?Type != 'NS' && Type != 'SOA']" --output json 2>/dev/null)

                local record_count
                record_count=$(echo "$record_sets" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

                if [[ "$record_count" -gt 0 ]]; then
                    echo "  [DELETE] Deleting $record_count record(s) from zone $zone_name..."
                    # Build a batch delete request
                    local changes
                    changes=$(echo "$record_sets" | python3 -c "
import json, sys
records = json.load(sys.stdin)
changes = [{'Action': 'DELETE', 'ResourceRecordSet': r} for r in records]
print(json.dumps({'Changes': changes}))
")
                    aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" \
                        --change-batch "$changes" 2>&1 | sed 's/^/    /' || true
                fi

                do_delete "Hosted Zone $zone_id ($zone_name)" \
                    aws route53 delete-hosted-zone --id "$zone_id"

                # Also clean up NS delegation records from the parent zone
                local parent_zone_id
                parent_zone_id=$(aws route53 list-hosted-zones \
                    --query "HostedZones[?Name=='${BASE_DOMAIN}.'].Id" --output text 2>/dev/null)
                if [[ -n "$parent_zone_id" ]]; then
                    local cluster_subdomain="${zone_name%.${BASE_DOMAIN}.}"
                    local ns_record
                    ns_record=$(aws route53 list-resource-record-sets --hosted-zone-id "$parent_zone_id" \
                        --query "ResourceRecordSets[?Name=='${zone_name}' && Type=='NS']" --output json 2>/dev/null)
                    local ns_count
                    ns_count=$(echo "$ns_record" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
                    if [[ "$ns_count" -gt 0 ]]; then
                        echo "  [DELETE] Removing NS delegation from parent zone for $zone_name"
                        local ns_changes
                        ns_changes=$(echo "$ns_record" | python3 -c "
import json, sys
records = json.load(sys.stdin)
changes = [{'Action': 'DELETE', 'ResourceRecordSet': r} for r in records]
print(json.dumps({'Changes': changes}))
")
                        aws route53 change-resource-record-sets --hosted-zone-id "$parent_zone_id" \
                            --change-batch "$ns_changes" 2>&1 | sed 's/^/    /' || true
                    fi
                fi
            fi
        fi
    done <<< "$zones"
}

# --- EBS Volumes (orphaned) ---
delete_ebs_volumes() {
    section "EBS Volumes"

    local volumes
    volumes=$(aws ec2 describe-volumes --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'Volumes[*].[VolumeId, Size, State, Tags[?Key==`Name`].Value | [0], Tags[?Key==`apicurio/cluster`].Value | [0]]' \
        --output text 2>/dev/null)

    if [[ -z "$volumes" ]]; then
        echo "  No EBS volumes found."
        return
    fi

    while IFS=$'\t' read -r vol_id size state name cluster; do
        found "Volume $vol_id (${size}GB, $state) ($name) [cluster: $cluster]"
        if [[ "$state" == "available" ]]; then
            do_delete "Volume $vol_id ($name)" \
                aws ec2 delete-volume --region "$REGION" --volume-id "$vol_id"
        else
            echo "  [NOTE] Volume $vol_id is $state - will be available after instance termination"
            if [[ "$DELETE_MODE" == "true" ]]; then
                echo "  [DEFER] Will attempt deletion after instances are terminated"
            fi
        fi
    done <<< "$volumes"
}

# --- Deferred EBS volume cleanup (after instances are terminated) ---
delete_deferred_volumes() {
    if [[ "$DELETE_MODE" != "true" ]]; then
        return
    fi

    local volumes
    volumes=$(aws ec2 describe-volumes --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" "Name=status,Values=available" \
        --query 'Volumes[*].[VolumeId, Tags[?Key==`Name`].Value | [0]]' \
        --output text 2>/dev/null)

    if [[ -z "$volumes" ]]; then
        return
    fi

    section "Deferred EBS Volume Cleanup"
    while IFS=$'\t' read -r vol_id name; do
        do_delete "Volume $vol_id ($name)" \
            aws ec2 delete-volume --region "$REGION" --volume-id "$vol_id"
    done <<< "$volumes"
}

# --- Network Interfaces ---
delete_network_interfaces() {
    section "Network Interfaces"

    local enis
    enis=$(aws ec2 describe-network-interfaces --region "$REGION" \
        --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" \
        --query 'NetworkInterfaces[*].[NetworkInterfaceId, Status, VpcId, Description]' \
        --output text 2>/dev/null)

    if [[ -z "$enis" ]]; then
        echo "  No network interfaces found."
        return
    fi

    while IFS=$'\t' read -r eni_id status vpc_id description; do
        found "ENI $eni_id ($status) [vpc: $vpc_id] $description"
        if [[ "$DELETE_MODE" == "true" ]]; then
            if [[ "$status" == "in-use" ]]; then
                local attachment_id
                attachment_id=$(aws ec2 describe-network-interfaces --region "$REGION" \
                    --network-interface-ids "$eni_id" \
                    --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null)
                if [[ -n "$attachment_id" && "$attachment_id" != "None" ]]; then
                    aws ec2 detach-network-interface --region "$REGION" \
                        --attachment-id "$attachment_id" --force 2>/dev/null || true
                    sleep 2
                fi
            fi
        fi
        do_delete "ENI $eni_id" \
            aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$eni_id"
    done <<< "$enis"
}

# ==========================================
# Main execution - order matters!
# ==========================================

echo ""
if [[ "$DELETE_MODE" == "true" ]]; then
    important "MODE: DELETE - Resources will be permanently removed!"
    echo ""
    echo "You have 5 seconds to cancel (Ctrl+C)..."
    sleep 5
else
    important "MODE: DRY-RUN - No resources will be modified. Use --delete to remove them."
fi

echo ""
echo "Region: $REGION"
echo "Tag filter: ${TAG_KEY}=${TAG_VALUE}"

# Delete in dependency order:
# 1. Instances (depend on SGs, subnets, volumes)
delete_instances

# 2. Load balancers (depend on SGs, subnets)
delete_load_balancers

# 3. NAT gateways (depend on EIPs, subnets) - includes wait
delete_nat_gateways

# 4. EBS volumes (depend on instances)
delete_ebs_volumes

# 5. Network interfaces
delete_network_interfaces

# 6. Elastic IPs (after NAT gateways are deleted)
delete_elastic_ips

# 7. Internet gateways (must detach from VPC first)
delete_internet_gateways

# 8. Subnets (after instances, LBs, NAT gateways)
delete_subnets

# 9. Route tables (after subnets)
delete_route_tables

# 10. VPC endpoints
delete_vpc_endpoints

# 11. Security groups (after instances, LBs, ENIs)
delete_security_groups

# 12. VPCs (after everything else in the VPC)
delete_vpcs

# 13. S3 buckets
delete_s3_buckets

# 14. IAM resources (independent)
delete_iam_resources

# 15. Route53 sub-zones (last, independent)
delete_hosted_zones

# 16. Retry deferred volume deletions
delete_deferred_volumes

# --- Summary ---
section "Summary"
echo "  Total resources found: $TOTAL_FOUND"
if [[ "$DELETE_MODE" == "true" ]]; then
    echo "  Total resources deleted: $TOTAL_DELETED"
else
    echo "  Run with --delete to remove these resources."
    if [[ "$DELETE_HOSTED_ZONES" != "true" ]]; then
        echo "  Run with --delete --delete-hosted-zones to also remove cluster Route53 sub-zones."
    fi
fi
echo ""
