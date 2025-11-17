#!/usr/bin/env python3
"""
Unified Pattern System - Cross-Stack Validator for Ash + DaisyUI + BMAD
"""

from typing import Dict, List, Any, Optional
from pathlib import Path
import re

class CrossStackValidator:
    """Validates consistency across Ash, DaisyUI, and BMAD layers"""

    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.pattern_rules = self.load_pattern_rules()
        self.validation_results = {}

    def load_pattern_rules(self) -> Dict[str, Any]:
        """Load unified pattern matching rules"""
        return {
            "resource_mapping": {
                "user": {
                    "ash_resource": "UserResource",
                    "daisyui_component": "user-card",
                    "bmad_workflow": "user_lifecycle"
                },
                "post": {
                    "ash_resource": "PostResource",
                    "daisyui_component": "post-card",
                    "bmad_workflow": "post_lifecycle"
                }
            },
            "action_mapping": {
                "show": {"modifier": "detail", "btn_class": "btn-primary"},
                "list": {"modifier": "list", "btn_class": "btn-secondary"},
                "create": {"modifier": "form", "btn_class": "btn-success"},
                "edit": {"modifier": "form", "btn_class": "btn-warning"}
            },
            "theme_colors": {
                "primary": "hsl(222.2 47.4% 11.2%)",
                "secondary": "hsl(210 40% 96%)",
                "accent": "hsl(210 40% 96%)",
                "neutral": "hsl(215.4 16.3% 46.9%)"
            }
        }

    def validate_full_stack(self) -> Dict[str, Any]:
        """Run complete cross-stack validation"""
        print("🔄 Running unified cross-stack validation...")

        results = {
            "overall_status": "passed",
            "checks": {},
            "issues": [],
            "summary": ""
        }

        # Core validation checks
        checks = [
            ("pattern_consistency", self.validate_pattern_consistency),
            ("theme_synchronization", self.validate_theme_sync),
            ("naming_convention", self.validate_naming_convention),
            ("component_mapping", self.validate_component_mapping),
            ("workflow_integration", self.validate_workflow_integration)
        ]

        for check_name, check_func in checks:
            try:
                result = check_func()
                results["checks"][check_name] = result
                if not result["passed"]:
                    results["overall_status"] = "failed"
                    results["issues"].extend(result.get("issues", []))
            except Exception as e:
                results["checks"][check_name] = {
                    "passed": False,
                    "issues": [f"Validation error: {str(e)}"]
                }
                results["overall_status"] = "failed"

        # Generate summary
        if results["overall_status"] == "passed":
            results["summary"] = "🎉 All cross-stack validations passed! Your Ash + DaisyUI + BMAD integration is perfectly synchronized."
        else:
            results["summary"] = f"⚠️ {len(results['issues'])} validation issues found. Please review and fix."

        return results

    def validate_pattern_consistency(self) -> Dict[str, Any]:
        """Validate pattern consistency across layers"""
        print("  📋 Checking pattern consistency...")

        issues = []

        # Check Ash resource naming
        ash_files = list(self.project_path.glob("**/*.ex"))
        ash_resources = self.extract_ash_resources(ash_files)

        # Check DaisyUI component naming
        component_files = list(self.project_path.glob("**/*.html")) + list(self.project_path.glob("**/*.heex"))
        daisyui_components = self.extract_daisyui_components(component_files)

        # Validate resource-component mapping
        for resource_name, resource_info in self.pattern_rules["resource_mapping"].items():
            if resource_info["ash_resource"] not in ash_resources:
                issues.append(f"Ash resource '{resource_info['ash_resource']}' not found")
            if resource_info["daisyui_component"] not in daisyui_components:
                issues.append(f"DaisyUI component '{resource_info['daisyui_component']}' not found")

        return {
            "passed": len(issues) == 0,
            "issues": issues,
            "ash_resources_found": len(ash_resources),
            "daisyui_components_found": len(daisyui_components)
        }

    def validate_theme_sync(self) -> Dict[str, Any]:
        """Validate theme synchronization"""
        print("  🎨 Checking theme synchronization...")

        issues = []
        themes_found = []

        # Check for theme configuration in various files
        config_files = [
            self.project_path / "config" / "config.exs",
            self.project_path / "assets" / "css" / "app.css",
            self.project_path / "tailwind.config.js"
        ]

        for config_file in config_files:
            if config_file.exists():
                content = config_file.read_text()
                for color_name, color_value in self.pattern_rules["theme_colors"].items():
                    if color_value in content:
                        themes_found.append(f"{config_file.name}:{color_name}")

        if len(themes_found) < 3:  # Expect at least some theme references
            issues.append("Limited theme synchronization found across configuration files")

        return {
            "passed": len(issues) == 0,
            "issues": issues,
            "theme_references_found": themes_found
        }

    def validate_naming_convention(self) -> Dict[str, Any]:
        """Validate naming convention consistency"""
        print("  📝 Checking naming conventions...")

        issues = []
        naming_violations = []

        # Pattern: resource_name → ResourceName → resource-name
        for resource_name in self.pattern_rules["resource_mapping"]:
            ash_resource = self.pattern_rules["resource_mapping"][resource_name]["ash_resource"]
            daisyui_component = self.pattern_rules["resource_mapping"][resource_name]["daisyui_component"]

            # Check Ash resource follows PascalCase
            if not re.match(r'^[A-Z][a-zA-Z0-9]*Resource$', ash_resource):
                naming_violations.append(f"Ash resource '{ash_resource}' doesn't follow PascalCase")

            # Check DaisyUI component follows kebab-case
            if not re.match(r'^[a-z]+(-[a-z]+)*$', daisyui_component):
                naming_violations.append(f"DaisyUI component '{daisyui_component}' doesn't follow kebab-case")

        return {
            "passed": len(naming_violations) == 0,
            "issues": naming_violations,
            "resources_checked": len(self.pattern_rules["resource_mapping"])
        }

    def validate_component_mapping(self) -> Dict[str, Any]:
        """Validate component mapping exists"""
        print("  🗺️ Checking component mappings...")

        issues = []
        mappings_found = 0

        for resource_name, mapping in self.pattern_rules["resource_mapping"].items():
            # Check if we have all required parts of the mapping
            if mapping.get("ash_resource") and mapping.get("daisyui_component") and mapping.get("bmad_workflow"):
                mappings_found += 1
            else:
                issues.append(f"Incomplete mapping for resource '{resource_name}'")

        return {
            "passed": mappings_found > 0,
            "issues": issues,
            "complete_mappings": mappings_found
        }

    def validate_workflow_integration(self) -> Dict[str, Any]:
        """Validate BMAD workflow integration"""
        print("  ⚙️ Checking workflow integration...")

        issues = []
        workflow_files = list(self.project_path.glob("**/*.yaml")) + list(self.project_path.glob("**/*.md"))

        bmad_workflows_found = 0
        for workflow_file in workflow_files:
            content = workflow_file.read_text().lower()
            if "workflow" in content or "bmad" in content:
                bmad_workflows_found += 1

        if bmad_workflows_found == 0:
            issues.append("No BMAD workflow files found")

        return {
            "passed": bmad_workflows_found > 0,
            "issues": issues,
            "workflow_files_found": bmad_workflows_found
        }

    def extract_ash_resources(self, files: List[Path]) -> List[str]:
        """Extract Ash resource names from files"""
        resources = []
        for file_path in files:
            if "resource" in file_path.name or file_path.parts[-2] == "resources":
                content = file_path.read_text()
                # Look for defmodule SomethingResource
                matches = re.findall(r'defmodule (\w+Resource)', content)
                resources.extend(matches)
        return resources

    def extract_daisyui_components(self, files: List[Path]) -> List[str]:
        """Extract DaisyUI component names from files"""
        components = []
        for file_path in files:
            content = file_path.read_text()
            # Look for common DaisyUI class patterns
            if "card" in content or "btn" in content or "modal" in content:
                # Extract potential component identifiers
                if "user-card" in content:
                    components.append("user-card")
                if "post-card" in content:
                    components.append("post-card")
        return components

def main():
    """Main validation entry point"""
    project_path = "."
    validator = CrossStackValidator(project_path)
    results = validator.validate_full_stack()

    print("\n" + "="*60)
    print("🔍 CROSS-STACK VALIDATION REPORT")
    print("="*60)
    print(f"Overall Status: {results['overall_status'].upper()}")
    print("\nChecks Performed:")
    for check_name, result in results["checks"].items():
        status = "✅ PASSED" if result["passed"] else "❌ FAILED"
        print(f"  {status} {check_name.replace('_', ' ').title()}")

    if results["issues"]:
        print("\nIssues Found:")
        for issue in results["issues"]:
            print(f"  ❌ {issue}")

    print(f"\n{results['summary']}")
    print("="*60)

if __name__ == "__main__":
    main()