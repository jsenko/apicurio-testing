#!/bin/bash

# Script to check for the existence of a hosted zone for apicurio-testing.org
# Uses AWS CLI to query Route53

set -e

DOMAIN_NAME="apicurio-testing.org"
CREATE_ZONE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --create)
            CREATE_ZONE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--create]"
            echo ""
            echo "Options:"
            echo "  --create    Create the hosted zone if it doesn't exist (default: false)"
            echo "  -h, --help  Show this help message"
            echo ""
            echo "By default, this script only checks for the existence of the hosted zone"
            echo "and fails if it doesn't exist. Use --create to automatically create it."
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "Checking for hosted zone: ${DOMAIN_NAME}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed or not in PATH"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: AWS credentials not configured or invalid"
    echo "Please run 'aws configure' or set appropriate environment variables"
    exit 1
fi

echo "Querying Route53 for hosted zone: ${DOMAIN_NAME}"

# Query Route53 for hosted zones matching the domain name
HOSTED_ZONE_INFO=$(aws route53 list-hosted-zones-by-name --dns-name "${DOMAIN_NAME}" --query "HostedZones[?Name=='${DOMAIN_NAME}.']" --output json)

# Check if any hosted zones were found
if [ "$(echo "${HOSTED_ZONE_INFO}" | jq '. | length')" -eq 0 ]; then
    echo "RESULT: No hosted zone found for domain '${DOMAIN_NAME}'"
    
    if [ "${CREATE_ZONE}" = false ]; then
        echo "ERROR: Hosted zone does not exist for domain '${DOMAIN_NAME}'"
        echo "Use --create flag to automatically create the hosted zone"
        exit 1
    fi
    
    echo "Creating hosted zone for domain '${DOMAIN_NAME}'..."
    
    # Create the hosted zone
    CREATE_RESULT=$(aws route53 create-hosted-zone \
        --name "${DOMAIN_NAME}" \
        --caller-reference "$(date +%s)-${DOMAIN_NAME}" \
        --hosted-zone-config Comment="Hosted zone for ${DOMAIN_NAME} created by ensure-hosted-zone.sh" \
        --output json)
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Hosted zone created for domain '${DOMAIN_NAME}'"
        
        # Extract hosted zone details
        HOSTED_ZONE_ID=$(echo "${CREATE_RESULT}" | jq -r '.HostedZone.Id' | sed 's|/hostedzone/||')
        
        # Add tags to the hosted zone
        echo "Adding tags to hosted zone..."
        TAG_RESULT=$(aws route53 change-tags-for-resource \
            --resource-type hostedzone \
            --resource-id "${HOSTED_ZONE_ID}" \
            --add-tags Key=app-code,Value=SRQE-001 Key=service-phase,Value=dev Key=cost-center,Value=704 \
            --output json)
        
        if [ $? -eq 0 ]; then
            echo "SUCCESS: Tags added to hosted zone"
            echo "  Tags: app-code=SRQE-001, service-phase=dev, cost-center=704"
        else
            echo "WARNING: Failed to add tags to hosted zone (zone creation was successful)"
        fi
        
        # Get the nameservers for the new hosted zone
        NAMESERVERS=$(echo "${CREATE_RESULT}" | jq -r '.DelegationSet.NameServers[]')
        
        echo "  Hosted Zone ID: ${HOSTED_ZONE_ID}"
        echo "  Domain: ${DOMAIN_NAME}"
        echo ""
        echo "New hosted zone nameservers:"
        echo "${NAMESERVERS}" | while read -r ns; do
            echo "  - ${ns}"
        done
        echo ""
        
        # Check if domain is registered in Route 53 and update nameservers automatically
        echo "Checking if domain is registered in Route 53..."
        DOMAIN_INFO=$(aws route53domains get-domain-detail --domain-name "${DOMAIN_NAME}" --output json 2>/dev/null || echo "null")
        
        if [ "${DOMAIN_INFO}" != "null" ]; then
            echo "Domain found in Route 53 registration. Updating nameservers automatically..."
            
            # Get current nameservers for comparison
            CURRENT_NS=$(echo "${DOMAIN_INFO}" | jq -r '.Nameservers[].Name')
            echo "Current nameservers:"
            echo "${CURRENT_NS}" | while read -r ns; do
                echo "  - ${ns}"
            done
            echo ""
            
            # Prepare nameservers for the update command
            NS_JSON=$(echo "${NAMESERVERS}" | jq -R -s 'split("\n") | map(select(length > 0)) | map({Name: .})')
            
            # Update the domain nameservers
            UPDATE_RESULT=$(aws route53domains update-domain-nameservers \
                --domain-name "${DOMAIN_NAME}" \
                --nameservers "${NS_JSON}" \
                --output json)
            
            if [ $? -eq 0 ]; then
                OPERATION_ID=$(echo "${UPDATE_RESULT}" | jq -r '.OperationId')
                echo "SUCCESS: Domain nameservers updated automatically!"
                echo "  Operation ID: ${OPERATION_ID}"
                echo "  DNS propagation may take up to 48 hours"
            else
                echo "WARNING: Failed to update domain nameservers automatically"
                echo "Please update them manually in the Route 53 console"
            fi
        else
            echo "Domain not found in Route 53 registration or access denied."
            echo "MANUAL ACTION REQUIRED: Update your domain registration to use these nameservers:"
            echo "${NAMESERVERS}" | while read -r ns; do
                echo "  - ${ns}"
            done
            echo ""
            echo "Instructions:"
            echo "1. Log into your domain registrar's control panel"
            echo "2. Navigate to DNS/Nameserver settings for ${DOMAIN_NAME}"
            echo "3. Replace the current nameservers with the AWS nameservers listed above"
            echo "4. Save the changes (DNS propagation may take up to 48 hours)"
        fi
        echo ""
        
        exit 0
    else
        echo "ERROR: Failed to create hosted zone for domain '${DOMAIN_NAME}'"
        exit 1
    fi
else
    echo "RESULT: Hosted zone found for domain '${DOMAIN_NAME}'"
    
    # Extract and display hosted zone details
    HOSTED_ZONE_ID=$(echo "${HOSTED_ZONE_INFO}" | jq -r '.[0].Id' | sed 's|/hostedzone/||')
    RECORD_COUNT=$(echo "${HOSTED_ZONE_INFO}" | jq -r '.[0].ResourceRecordSetCount')
    
    echo "  Hosted Zone ID: ${HOSTED_ZONE_ID}"
    echo "  Record Count: ${RECORD_COUNT}"
    echo "  Domain: ${DOMAIN_NAME}"
    
    # Also show the nameservers for the existing hosted zone
    echo ""
    echo "Current nameservers for this hosted zone:"
    NS_RECORDS=$(aws route53 list-resource-record-sets --hosted-zone-id "/hostedzone/${HOSTED_ZONE_ID}" --query "ResourceRecordSets[?Type=='NS'].ResourceRecords[].Value" --output json)
    echo "${NS_RECORDS}" | jq -r '.[]' | while read -r ns; do
        echo "  - ${ns}"
    done
    
    # Show current tags for the existing hosted zone
    echo ""
    echo "Current tags for this hosted zone:"
    EXISTING_TAGS=$(aws route53 list-tags-for-resource --resource-type hostedzone --resource-id "${HOSTED_ZONE_ID}" --output json 2>/dev/null || echo '{"ResourceTagSet":{"Tags":[]}}')
    TAG_COUNT=$(echo "${EXISTING_TAGS}" | jq '.ResourceTagSet.Tags | length')
    
    if [ "${TAG_COUNT}" -gt 0 ]; then
        echo "${EXISTING_TAGS}" | jq -r '.ResourceTagSet.Tags[] | "  - \(.Key)=\(.Value)"'
    else
        echo "  No tags found"
    fi
    
    exit 0
fi
