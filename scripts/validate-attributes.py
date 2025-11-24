#!/usr/bin/env python3
"""
Validate Okta user attribute YAML definitions.
Checks for syntax errors, naming conflicts, and business rule violations.
"""

import os
import sys
import yaml
import json
import re
from typing import Dict, List, Any, Set, Tuple
from pathlib import Path
from datetime import datetime

# Color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

# Reserved Okta attribute names that shouldn't be used
RESERVED_ATTRIBUTES = {
    'login', 'email', 'secondEmail', 'firstName', 'lastName',
    'middleName', 'honorificPrefix', 'honorificSuffix', 'title',
    'displayName', 'nickName', 'profileUrl', 'primaryPhone',
    'mobilePhone', 'streetAddress', 'city', 'state', 'zipCode',
    'countryCode', 'postalAddress', 'preferredLanguage', 'locale',
    'timezone', 'userType', 'employeeNumber', 'costCenter',
    'organization', 'division', 'department', 'managerId', 'manager'
}

# Valid attribute types
VALID_TYPES = {'string', 'boolean', 'number', 'integer', 'array', 'object'}

# Valid master values
VALID_MASTERS = {'PROFILE_MASTER', 'OKTA', 'OVERRIDE'}

# Valid permission values
VALID_PERMISSIONS = {'READ_WRITE', 'READ_ONLY', 'HIDE'}

# Valid scope values
VALID_SCOPES = {'NONE', 'SELF', 'GROUP'}

# Valid unique values
VALID_UNIQUE = {'UNIQUE_VALIDATED', 'NOT_UNIQUE'}

class AttributeValidator:
    def __init__(self, base_dir: str = None):
        """Initialize validator with base directory."""
        self.base_dir = Path(base_dir) if base_dir else Path.cwd()
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []
        
    def load_yaml_file(self, file_path: Path) -> Dict[str, Any]:
        """Load and parse a YAML file."""
        try:
            with open(file_path, 'r') as f:
                return yaml.safe_load(f)
        except yaml.YAMLError as e:
            self.errors.append(f"YAML syntax error in {file_path}: {e}")
            return {}
        except FileNotFoundError:
            self.errors.append(f"File not found: {file_path}")
            return {}
        except Exception as e:
            self.errors.append(f"Error loading {file_path}: {e}")
            return {}
    
    def validate_attribute_name(self, name: str) -> None:
        """Validate attribute naming conventions."""
        # Check if it's a reserved name
        if name in RESERVED_ATTRIBUTES:
            self.warnings.append(f"Attribute '{name}' uses a reserved Okta attribute name")
        
        # Check naming convention (lowercase with underscores)
        if not re.match(r'^[a-z][a-z0-9_]{1,49}$', name):
            self.errors.append(
                f"Attribute '{name}' doesn't follow naming convention "
                "(lowercase letters, numbers, underscores, 2-50 chars)"
            )
        
        # Check for problematic patterns
        if name.startswith('_') or name.endswith('_'):
            self.warnings.append(f"Attribute '{name}' starts or ends with underscore")
        
        if '__' in name:
            self.warnings.append(f"Attribute '{name}' contains double underscores")
    
    def validate_attribute(self, attr: Dict[str, Any]) -> None:
        """Validate a single attribute definition."""
        name = attr.get('name', 'unknown')
        
        # Required fields
        if 'name' not in attr:
            self.errors.append("Attribute missing 'name' field")
            return
        
        if 'type' not in attr:
            self.errors.append(f"Attribute '{name}' missing 'type' field")
            return
        
        # Validate name
        self.validate_attribute_name(name)
        
        # Validate type
        attr_type = attr.get('type')
        if attr_type not in VALID_TYPES:
            self.errors.append(
                f"Attribute '{name}' has invalid type '{attr_type}'. "
                f"Valid types: {VALID_TYPES}"
            )
        
        # Validate master
        master = attr.get('master')
        if master and master not in VALID_MASTERS:
            self.errors.append(
                f"Attribute '{name}' has invalid master '{master}'. "
                f"Valid values: {VALID_MASTERS}"
            )
        
        # Validate permissions
        permissions = attr.get('permissions')
        if permissions and permissions not in VALID_PERMISSIONS:
            self.errors.append(
                f"Attribute '{name}' has invalid permissions '{permissions}'. "
                f"Valid values: {VALID_PERMISSIONS}"
            )
        
        # Validate scope
        scope = attr.get('scope')
        if scope and scope not in VALID_SCOPES:
            self.errors.append(
                f"Attribute '{name}' has invalid scope '{scope}'. "
                f"Valid values: {VALID_SCOPES}"
            )
        
        # Validate unique
        unique = attr.get('unique')
        if unique and unique not in VALID_UNIQUE:
            self.errors.append(
                f"Attribute '{name}' has invalid unique value '{unique}'. "
                f"Valid values: {VALID_UNIQUE}"
            )
        
        # Type-specific validations
        self.validate_type_specific(name, attr)
        
        # Check for deprecated or problematic configurations
        self.check_best_practices(name, attr)
    
    def validate_type_specific(self, name: str, attr: Dict[str, Any]) -> None:
        """Validate type-specific constraints."""
        attr_type = attr.get('type')
        
        if attr_type == 'string':
            # String-specific validations
            if 'min_length' in attr and 'max_length' in attr:
                min_len = attr['min_length']
                max_len = attr['max_length']
                if min_len > max_len:
                    self.errors.append(
                        f"Attribute '{name}' has min_length ({min_len}) > "
                        f"max_length ({max_len})"
                    )
            
            # Check pattern is valid regex
            if 'pattern' in attr:
                try:
                    re.compile(attr['pattern'])
                except re.error as e:
                    self.errors.append(
                        f"Attribute '{name}' has invalid regex pattern: {e}"
                    )
            
            # Check enum values
            if 'enum' in attr and not isinstance(attr['enum'], list):
                self.errors.append(f"Attribute '{name}' enum must be a list")
        
        elif attr_type == 'array':
            # Array must have array_type
            if 'array_type' not in attr:
                self.errors.append(
                    f"Attribute '{name}' has type 'array' but missing 'array_type'"
                )
            
            # Check array_enum
            if 'array_enum' in attr and not isinstance(attr['array_enum'], list):
                self.errors.append(f"Attribute '{name}' array_enum must be a list")
        
        elif attr_type == 'boolean':
            # Boolean shouldn't have certain string properties
            invalid_props = ['pattern', 'min_length', 'max_length', 'enum']
            for prop in invalid_props:
                if prop in attr:
                    self.warnings.append(
                        f"Attribute '{name}' is boolean but has '{prop}' property"
                    )
        
        elif attr_type in ['number', 'integer']:
            # Number shouldn't have string properties
            invalid_props = ['pattern', 'min_length', 'max_length', 'enum']
            for prop in invalid_props:
                if prop in attr:
                    self.warnings.append(
                        f"Attribute '{name}' is {attr_type} but has '{prop}' property"
                    )
    
    def check_best_practices(self, name: str, attr: Dict[str, Any]) -> None:
        """Check for best practices and common issues."""
        # Check for missing description
        if 'description' not in attr:
            self.warnings.append(f"Attribute '{name}' missing description")
        
        # Check for missing display_name
        if 'display_name' not in attr:
            self.info.append(f"Attribute '{name}' missing display_name")
        
        # Warn about OVERRIDE master without master_override_priority
        if attr.get('master') == 'OVERRIDE' and 'master_override_priority' not in attr:
            self.errors.append(
                f"Attribute '{name}' has master 'OVERRIDE' but missing "
                "'master_override_priority'"
            )
        
        # Check for potentially sensitive data
        sensitive_patterns = ['password', 'secret', 'token', 'key', 'credential']
        name_lower = name.lower()
        if any(pattern in name_lower for pattern in sensitive_patterns):
            if attr.get('permissions') != 'HIDE':
                self.warnings.append(
                    f"Attribute '{name}' appears sensitive but permissions "
                    f"is not 'HIDE'"
                )
        
        # Check unique constraints on arrays/objects
        if attr.get('type') in ['array', 'object'] and attr.get('unique'):
            self.warnings.append(
                f"Attribute '{name}' is {attr.get('type')} with unique "
                "constraint - this may not work as expected"
            )
    
    def validate_overrides(self, overrides: List[Dict[str, Any]], 
                          base_attrs: Dict[str, Any]) -> None:
        """Validate that overrides reference existing base attributes."""
        base_names = {attr['name'] for attr in base_attrs if 'name' in attr}
        
        for override in overrides:
            name = override.get('name')
            if not name:
                self.errors.append("Override missing 'name' field")
                continue
            
            if name not in base_names:
                self.warnings.append(
                    f"Override for '{name}' doesn't match any base attribute"
                )
    
    def validate_file(self, file_path: Path, is_override: bool = False) -> Dict[str, Any]:
        """Validate a single attribute file."""
        data = self.load_yaml_file(file_path)
        
        if not data:
            return {}
        
        # Check version
        if 'version' not in data:
            self.warnings.append(f"{file_path}: Missing version field")
        
        # Check metadata
        if 'metadata' not in data:
            self.info.append(f"{file_path}: Missing metadata section")
        
        if is_override:
            # Validate override file
            if 'overrides' in data:
                for override in data.get('overrides', []):
                    # Only validate override structure, not full attribute
                    if 'name' not in override:
                        self.errors.append(f"{file_path}: Override missing 'name'")
            
            if 'additions' in data:
                for attr in data.get('additions', []):
                    self.validate_attribute(attr)
        else:
            # Validate base attribute file
            if 'attributes' not in data:
                self.errors.append(f"{file_path}: Missing 'attributes' section")
            else:
                for attr in data.get('attributes', []):
                    self.validate_attribute(attr)
        
        return data
    
    def check_duplicates(self, all_attributes: List[Dict[str, Any]]) -> None:
        """Check for duplicate attribute names."""
        seen = {}
        for attr in all_attributes:
            name = attr.get('name')
            if name:
                if name in seen:
                    self.errors.append(
                        f"Duplicate attribute name '{name}' found"
                    )
                seen[name] = True
    
    def validate_all(self) -> bool:
        """Validate all attribute files."""
        print(f"{Colors.HEADER}{'='*60}{Colors.ENDC}")
        print(f"{Colors.HEADER}Okta Attribute Validation{Colors.ENDC}")
        print(f"{Colors.HEADER}{'='*60}{Colors.ENDC}\n")
        
        # Find attribute files
        base_file = self.base_dir / 'attributes' / 'definitions' / 'custom_attributes.yaml'
        override_dir = self.base_dir / 'attributes' / 'overrides'
        
        # Validate base attributes
        print(f"{Colors.OKCYAN}Validating base attributes...{Colors.ENDC}")
        base_data = self.validate_file(base_file, is_override=False)
        base_attrs = base_data.get('attributes', [])
        print(f"  ✓ Found {len(base_attrs)} base attributes\n")
        
        # Check for duplicates in base
        self.check_duplicates(base_attrs)
        
        # Validate override files
        print(f"{Colors.OKCYAN}Validating environment overrides...{Colors.ENDC}")
        environments = ['dev', 'qa', 'val', 'prod']
        
        for env in environments:
            override_file = override_dir / f'{env}.yaml'
            if override_file.exists():
                print(f"  Checking {env}...")
                override_data = self.validate_file(override_file, is_override=True)
                
                # Validate overrides against base
                if 'overrides' in override_data:
                    self.validate_overrides(
                        override_data['overrides'], 
                        base_attrs
                    )
                
                # Count changes
                num_overrides = len(override_data.get('overrides', []))
                num_additions = len(override_data.get('additions', []))
                print(f"    ✓ {num_overrides} overrides, {num_additions} additions")
            else:
                self.info.append(f"Override file not found: {override_file}")
        
        # Print summary
        print(f"\n{Colors.HEADER}{'='*60}{Colors.ENDC}")
        print(f"{Colors.HEADER}Validation Summary{Colors.ENDC}")
        print(f"{Colors.HEADER}{'='*60}{Colors.ENDC}\n")
        
        # Print errors
        if self.errors:
            print(f"{Colors.FAIL}❌ ERRORS ({len(self.errors)}):{Colors.ENDC}")
            for error in self.errors:
                print(f"  • {error}")
            print()
        
        # Print warnings
        if self.warnings:
            print(f"{Colors.WARNING}⚠️  WARNINGS ({len(self.warnings)}):{Colors.ENDC}")
            for warning in self.warnings:
                print(f"  • {warning}")
            print()
        
        # Print info
        if self.info:
            print(f"{Colors.OKBLUE}ℹ️  INFO ({len(self.info)}):{Colors.ENDC}")
            for info in self.info:
                print(f"  • {info}")
            print()
        
        # Final status
        if self.errors:
            print(f"{Colors.FAIL}❌ Validation FAILED{Colors.ENDC}")
            return False
        else:
            print(f"{Colors.OKGREEN}✅ Validation PASSED{Colors.ENDC}")
            return True

def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Validate Okta user attribute YAML definitions'
    )
    parser.add_argument(
        '--dir', '-d',
        default='.',
        help='Base directory containing attributes folder (default: current)'
    )
    parser.add_argument(
        '--strict',
        action='store_true',
        help='Treat warnings as errors'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output results as JSON'
    )
    
    args = parser.parse_args()
    
    validator = AttributeValidator(args.dir)
    success = validator.validate_all()
    
    if args.json:
        # Output as JSON for CI/CD integration
        result = {
            'success': success and (not args.strict or not validator.warnings),
            'errors': validator.errors,
            'warnings': validator.warnings,
            'info': validator.info,
            'timestamp': datetime.now().isoformat()
        }
        print(json.dumps(result, indent=2))
        
    if args.strict and validator.warnings:
        success = False
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()