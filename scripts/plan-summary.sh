#!/bin/bash
# ========================================
# Terraform Plan Summary Generator
# ========================================
# Generates a human-readable summary of Terraform plan output
# Usage: ./plan-summary.sh <environment> <region>

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Arguments
ENV="${1:-}"
REGION="${2:-}"

if [[ -z "$ENV" || -z "$REGION" ]]; then
    echo "Usage: $0 <environment> <region>"
    echo "Example: $0 dev apac"
    exit 1
fi

# Validate environment and region
VALID_ENVS="dev qa val prod"
VALID_REGIONS="apac emea"

if [[ ! " $VALID_ENVS " =~ " $ENV " ]]; then
    echo -e "${RED}Error: Invalid environment '$ENV'${NC}"
    echo "Valid environments: $VALID_ENVS"
    exit 1
fi

if [[ ! " $VALID_REGIONS " =~ " $REGION " ]]; then
    echo -e "${RED}Error: Invalid region '$REGION'${NC}"
    echo "Valid regions: $VALID_REGIONS"
    exit 1
fi

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$PROJECT_ROOT/environments/$REGION/$ENV"
PLAN_FILE="$ENV_DIR/tfplan"
PLAN_JSON="$ENV_DIR/tfplan.json"

# Function to print section headers
print_header() {
    echo -e "\n${CYAN}$1${NC}"
    echo "$(printf '=%.0s' {1..60})"
}

# Function to extract plan stats
extract_plan_stats() {
    local plan_output="$1"
    
    local to_add=$(echo "$plan_output" | grep -oP '\d+(?= to add)' || echo "0")
    local to_change=$(echo "$plan_output" | grep -oP '\d+(?= to change)' || echo "0")
    local to_destroy=$(echo "$plan_output" | grep -oP '\d+(?= to destroy)' || echo "0")
    
    echo "$to_add|$to_change|$to_destroy"
}

# Main execution
main() {
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}Terraform Plan Summary${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "Environment: ${GREEN}$ENV${NC}"
    echo -e "Region:      ${GREEN}$REGION${NC}"
    echo -e "Directory:   ${GREEN}$ENV_DIR${NC}"
    echo -e "Timestamp:   ${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    
    # Check if we're in the right directory
    if [[ ! -d "$ENV_DIR" ]]; then
        echo -e "${RED}Error: Environment directory not found: $ENV_DIR${NC}"
        exit 1
    fi
    
    cd "$ENV_DIR"
    
    # Initialize Terraform if needed
    if [[ ! -d ".terraform" ]]; then
        print_header "Initializing Terraform..."
        terraform init -input=false -no-color
    fi
    
    # Generate plan
    print_header "Generating Terraform Plan..."
    
    # Capture plan output
    if terraform plan -input=false -no-color -out="$PLAN_FILE" > tfplan.txt 2>&1; then
        echo -e "${GREEN}✓ Plan generated successfully${NC}"
    else
        echo -e "${RED}✗ Plan failed${NC}"
        cat tfplan.txt
        exit 1
    fi
    
    # Convert plan to JSON for analysis
    terraform show -json "$PLAN_FILE" > "$PLAN_JSON" 2>/dev/null || true
    
    # Extract statistics
    print_header "Plan Statistics"
    
    PLAN_OUTPUT=$(cat tfplan.txt)
    STATS=$(extract_plan_stats "$PLAN_OUTPUT")
    IFS='|' read -r TO_ADD TO_CHANGE TO_DESTROY <<< "$STATS"
    
    # Display stats with colors
    if [[ "$TO_ADD" -gt 0 ]]; then
        echo -e "  ${GREEN}+ To Add:     $TO_ADD${NC}"
    else
        echo -e "  ${CYAN}+ To Add:     $TO_ADD${NC}"
    fi
    
    if [[ "$TO_CHANGE" -gt 0 ]]; then
        echo -e "  ${YELLOW}~ To Change:  $TO_CHANGE${NC}"
    else
        echo -e "  ${CYAN}~ To Change:  $TO_CHANGE${NC}"
    fi
    
    if [[ "$TO_DESTROY" -gt 0 ]]; then
        echo -e "  ${RED}- To Destroy: $TO_DESTROY${NC}"
    else
        echo -e "  ${CYAN}- To Destroy: $TO_DESTROY${NC}"
    fi
    
    # Parse JSON for detailed attribute changes
    if [[ -f "$PLAN_JSON" ]] && command -v jq &> /dev/null; then
        print_header "Attribute Changes Summary"
        
        # Extract custom attributes being changed
        echo -e "\n${BOLD}Custom Attributes:${NC}"
        
        # Additions
        ADDED_ATTRS=$(jq -r '.resource_changes[] | 
            select(.type == "okta_user_schema_property") | 
            select(.change.actions[] == "create") | 
            .change.after.index' "$PLAN_JSON" 2>/dev/null || true)
        
        if [[ -n "$ADDED_ATTRS" ]]; then
            echo -e "${GREEN}Adding:${NC}"
            echo "$ADDED_ATTRS" | while read -r attr; do
                echo -e "  + $attr"
            done
        fi
        
        # Modifications
        MODIFIED_ATTRS=$(jq -r '.resource_changes[] | 
            select(.type == "okta_user_schema_property") | 
            select(.change.actions[] == "update") | 
            .change.after.index' "$PLAN_JSON" 2>/dev/null || true)
        
        if [[ -n "$MODIFIED_ATTRS" ]]; then
            echo -e "${YELLOW}Modifying:${NC}"
            echo "$MODIFIED_ATTRS" | while read -r attr; do
                echo -e "  ~ $attr"
            done
        fi
        
        # Deletions
        DELETED_ATTRS=$(jq -r '.resource_changes[] | 
            select(.type == "okta_user_schema_property") | 
            select(.change.actions[] == "delete") | 
            .change.before.index' "$PLAN_JSON" 2>/dev/null || true)
        
        if [[ -n "$DELETED_ATTRS" ]]; then
            echo -e "${RED}Removing:${NC}"
            echo "$DELETED_ATTRS" | while read -r attr; do
                echo -e "  - $attr"
            done
        fi
    fi
    
    # Check for destructive changes
    print_header "Risk Assessment"
    
    if [[ "$TO_DESTROY" -gt 0 ]]; then
        echo -e "${RED}⚠️  WARNING: This plan contains destructive changes!${NC}"
        echo -e "${RED}   $TO_DESTROY resource(s) will be destroyed${NC}"
        echo -e "${YELLOW}   Review carefully before applying${NC}"
    elif [[ "$TO_CHANGE" -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  CAUTION: This plan modifies existing resources${NC}"
        echo -e "${YELLOW}   $TO_CHANGE resource(s) will be changed${NC}"
    else
        echo -e "${GREEN}✓ No destructive changes detected${NC}"
    fi
    
    # Environment-specific warnings
    if [[ "$ENV" == "prod" ]]; then
        echo -e "\n${RED}${BOLD}⚠️  PRODUCTION ENVIRONMENT${NC}"
        echo -e "${YELLOW}This is a production deployment. Please ensure:${NC}"
        echo "  • Change has been approved by CAB"
        echo "  • Maintenance window has been scheduled"
        echo "  • Rollback plan is ready"
        echo "  • On-call team has been notified"
    fi
    
    # Generate summary file
    print_header "Saving Summary"
    
    SUMMARY_FILE="$ENV_DIR/plan-summary-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "Terraform Plan Summary"
        echo "====================="
        echo "Environment: $ENV"
        echo "Region: $REGION"
        echo "Generated: $(date)"
        echo ""
        echo "Statistics:"
        echo "  To Add:     $TO_ADD"
        echo "  To Change:  $TO_CHANGE"
        echo "  To Destroy: $TO_DESTROY"
        echo ""
        echo "Full plan output:"
        echo "================="
        cat tfplan.txt
    } > "$SUMMARY_FILE"
    
    echo -e "Summary saved to: ${GREEN}$SUMMARY_FILE${NC}"
    
    # Final status
    echo -e "\n${BOLD}${BLUE}========================================${NC}"
    if [[ "$TO_ADD" -eq 0 && "$TO_CHANGE" -eq 0 && "$TO_DESTROY" -eq 0 ]]; then
        echo -e "${GREEN}✓ No changes required${NC}"
        exit 0
    else
        echo -e "${CYAN}ℹ Plan contains changes - review before applying${NC}"
        exit 0
    fi
}

# Run main function
main "$@"