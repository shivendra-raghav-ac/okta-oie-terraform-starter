#!/bin/bash
# ========================================
# Okta Deployment Smoke Tests
# ========================================
# Post-deployment validation for Okta attributes
# Usage: ./smoke-tests.sh <environment> <region>

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Arguments
ENV="${1:-}"
REGION="${2:-}"

if [[ -z "$ENV" || -z "$REGION" ]]; then
    echo "Usage: $0 <environment> <region>"
    echo "Example: $0 dev apac"
    exit 1
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$PROJECT_ROOT/environments/$REGION/$ENV"
RESULTS_FILE="/tmp/smoke-test-results-$(date +%Y%m%d-%H%M%S).log"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Function to print headers
print_header() {
    echo -e "\n${CYAN}$1${NC}"
    echo "$(printf '=%.0s' {1..60})"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "  Testing $test_name... "
    
    if eval "$test_command" >> "$RESULTS_FILE" 2>&1; then
        if [[ "$expected_result" == "0" ]]; then
            echo -e "${GREEN}✓ PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED (expected failure but passed)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        if [[ "$expected_result" != "0" ]]; then
            echo -e "${GREEN}✓ PASSED (expected failure)${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    fi
}

# Function to skip a test
skip_test() {
    local test_name="$1"
    local reason="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    
    echo -e "  Testing $test_name... ${YELLOW}⊘ SKIPPED${NC} ($reason)"
}

# Test Terraform state
test_terraform_state() {
    print_header "Terraform State Tests"
    
    cd "$ENV_DIR"
    
    # Test 1: Check terraform state exists
    run_test "Terraform state exists" "terraform state list > /dev/null"
    
    # Test 2: Check state is not empty
    run_test "State contains resources" "[[ \$(terraform state list | wc -l) -gt 0 ]]"
    
    # Test 3: Check for custom attributes in state
    run_test "Custom attributes in state" "terraform state list | grep -q okta_user_schema_property"
    
    # Test 4: Validate state integrity
    run_test "State integrity check" "terraform state pull > /dev/null"
}

# Test Okta API connectivity
test_okta_api() {
    print_header "Okta API Tests"
    
    # These would require actual Okta API calls
    # For now, we'll check if the credentials are set
    
    # Test 1: Check Okta environment variables
    if [[ -n "${OKTA_ORG_NAME:-}" ]]; then
        run_test "Okta org configured" "true"
    else
        skip_test "Okta org configured" "OKTA_ORG_NAME not set"
    fi
    
    # Test 2: Check Okta client ID
    if [[ -n "${OKTA_CLIENT_ID:-}" ]]; then
        run_test "Okta client ID configured" "true"
    else
        skip_test "Okta client ID configured" "OKTA_CLIENT_ID not set"
    fi
    
    # Note: Real implementation would make actual API calls
    skip_test "Okta API connectivity" "Requires API implementation"
    skip_test "User schema retrieval" "Requires API implementation"
}

# Test attribute configurations
test_attributes() {
    print_header "Attribute Configuration Tests"
    
    # Test 1: Base attributes file exists
    run_test "Base attributes file exists" \
        "[[ -f '$PROJECT_ROOT/attributes/definitions/custom_attributes.yaml' ]]"
    
    # Test 2: Override file exists for environment
    run_test "Override file exists for $ENV" \
        "[[ -f '$PROJECT_ROOT/attributes/overrides/$ENV.yaml' ]]"
    
    # Test 3: Validate YAML syntax
    if command -v python3 &> /dev/null; then
        run_test "Attribute YAML validation" \
            "python3 '$PROJECT_ROOT/scripts/validate-attributes.py' --dir '$PROJECT_ROOT'"
    else
        skip_test "Attribute YAML validation" "Python not installed"
    fi
    
    # Test 4: Check for required attributes
    cd "$ENV_DIR"
    
    # Get list of expected attributes from state
    if terraform state list | grep -q okta_user_schema_property; then
        # Count attributes in state
        ATTR_COUNT=$(terraform state list | grep -c okta_user_schema_property || true)
        run_test "Attributes deployed (count: $ATTR_COUNT)" "[[ $ATTR_COUNT -gt 0 ]]"
    else
        skip_test "Attributes deployed" "No attributes in state"
    fi
}

# Test deployment outputs
test_outputs() {
    print_header "Terraform Output Tests"
    
    cd "$ENV_DIR"
    
    # Test 1: Get outputs
    run_test "Terraform outputs accessible" "terraform output -json > /dev/null"
    
    # Test 2: Check specific outputs
    if terraform output -json > /dev/null 2>&1; then
        run_test "Environment output correct" \
            "[[ \$(terraform output -raw environment 2>/dev/null) == '$ENV' ]]"
        
        run_test "Region output correct" \
            "[[ \$(terraform output -raw region 2>/dev/null) == '$REGION' ]]"
    else
        skip_test "Environment output correct" "Outputs not available"
        skip_test "Region output correct" "Outputs not available"
    fi
}

# Test for common issues
test_common_issues() {
    print_header "Common Issues Tests"
    
    cd "$ENV_DIR"
    
    # Test 1: Check for drift
    echo -n "  Checking for configuration drift... "
    if terraform plan -detailed-exitcode > /dev/null 2>&1; then
        echo -e "${GREEN}✓ No drift detected${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        EXIT_CODE=$?
        if [[ $EXIT_CODE -eq 2 ]]; then
            echo -e "${YELLOW}⚠ Drift detected${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        else
            echo -e "${RED}✗ Plan failed${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test 2: Check for sensitive data in state
    echo -n "  Checking for exposed secrets... "
    if terraform state pull 2>/dev/null | grep -qE "(password|secret|token|key)" ; then
        echo -e "${YELLOW}⚠ Potential secrets in state${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    else
        echo -e "${GREEN}✓ No obvious secrets exposed${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Test environment-specific requirements
test_environment_specific() {
    print_header "Environment-Specific Tests ($ENV)"
    
    case "$ENV" in
        prod)
            # Production-specific tests
            echo "  Running production validation..."
            
            # Test: Required attributes are set as required
            skip_test "Required fields validation" "Requires API implementation"
            
            # Test: Permissions are restricted
            skip_test "Permission restrictions" "Requires API implementation"
            ;;
        dev)
            # Dev-specific tests
            echo "  Running development validation..."
            
            # Test: Test attributes exist
            skip_test "Test attributes present" "Requires state inspection"
            ;;
        *)
            echo "  No specific tests for $ENV environment"
            ;;
    esac
}

# Main execution
main() {
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}Okta Deployment Smoke Tests${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "Environment: ${GREEN}$ENV${NC}"
    echo -e "Region:      ${GREEN}$REGION${NC}"
    echo -e "Timestamp:   ${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "Results Log: ${GREEN}$RESULTS_FILE${NC}"
    
    # Initialize results file
    {
        echo "Smoke Test Results"
        echo "=================="
        echo "Environment: $ENV"
        echo "Region: $REGION"
        echo "Started: $(date)"
        echo ""
    } > "$RESULTS_FILE"
    
    # Run test suites
    test_terraform_state
    test_okta_api
    test_attributes
    test_outputs
    test_common_issues
    test_environment_specific
    
    # Summary
    print_header "Test Summary"
    
    echo -e "Total Tests:    ${BOLD}$TOTAL_TESTS${NC}"
    echo -e "Passed:         ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:         ${RED}$FAILED_TESTS${NC}"
    echo -e "Skipped:        ${YELLOW}$SKIPPED_TESTS${NC}"
    
    # Calculate success rate
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo -e "Success Rate:   ${BOLD}$SUCCESS_RATE%${NC}"
    fi
    
    # Final status
    echo -e "\n${BOLD}${BLUE}========================================${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✓ All smoke tests passed!${NC}"
        
        # Append success to results file
        {
            echo ""
            echo "Result: SUCCESS"
            echo "Completed: $(date)"
        } >> "$RESULTS_FILE"
        
        exit 0
    else
        echo -e "${RED}✗ $FAILED_TESTS test(s) failed${NC}"
        echo -e "${YELLOW}Review the results log for details: $RESULTS_FILE${NC}"
        
        # Append failure to results file
        {
            echo ""
            echo "Result: FAILURE ($FAILED_TESTS failed)"
            echo "Completed: $(date)"
        } >> "$RESULTS_FILE"
        
        # Exit with non-zero for CI/CD
        exit 1
    fi
}

# Run main function
main "$@"