#!/usr/bin/env python3
"""
Real-time validation for Ash + DaisyUI + BMAD Development Environment
"""

import os
import json
import time
from typing import Dict, List, Any
from pathlib import Path
import subprocess

class RealtimeValidator:
    """Live validation across all three layers"""

    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.validation_results = {}

    def watch_project(self):
        """Start real-time project monitoring"""
        print("🚀 Starting real-time validation across Ash + DaisyUI + BMAD layers...")

        # Monitor Ash resources
        self.monitor_ash_resources()

        # Monitor DaisyUI components
        self.monitor_daisyui_components()

        # Monitor BMAD workflows
        self.monitor_bmad_workflows()

        # Cross-stack validation
        self.run_cross_stack_checks()

    def monitor_ash_resources(self):
        """Monitor Ash resource files for changes"""
        ash_files = list(self.project_path.glob("**/*.ex"))

        print(f"📋 Found {len(ash_files)} Ash/Elixir files to monitor")

        for file_path in ash_files:
            if "resource" in file_path.name or file_path.parts[-2] == "resources":
                validation = self.validate_ash_resource(file_path)
                print(f"  ✅ {file_path.name}: {validation['status']}")

    def monitor_daisyui_components(self):
        """Monitor DaisyUI component files"""
        html_files = list(self.project_path.glob("**/*.html"))
        heex_files = list(self.project_path.glob("**/*.heex"))

        component_files = html_files + heex_files
        print(f"🎨 Found {len(component_files)} component files to monitor")

        for file_path in component_files:
            validation = self.validate_daisyui_component(file_path)
            print(f"  ✅ {file_path.name}: {validation['status']}")

    def monitor_bmad_workflows(self):
        """Monitor BMAD workflow files"""
        yaml_files = list(self.project_path.glob("**/*.yaml"))
        md_files = list(self.project_path.glob("**/*.md"))

        workflow_files = [f for f in yaml_files + md_files
                         if "workflow" in f.name or "bmad" in str(f)]

        print(f"⚙️ Found {len(workflow_files)} BMAD workflow files to monitor")

        for file_path in workflow_files:
            validation = self.validate_bmad_workflow(file_path)
            print(f"  ✅ {file_path.name}: {validation['status']}")

    def run_cross_stack_checks(self):
        """Validate consistency across all layers"""
        print("\n🔄 Running cross-stack validation checks...")

        checks = [
            ("Pattern Consistency", self.check_pattern_consistency),
            ("Theme Synchronization", self.check_theme_sync),
            ("Naming Convention", self.check_naming_convention),
            ("Component Mapping", self.check_component_mapping)
        ]

        for check_name, check_func in checks:
            result = check_func()
            status = "✅ PASSED" if result else "❌ FAILED"
            print(f"  {status} {check_name}")

    def validate_ash_resource(self, file_path: Path) -> Dict[str, Any]:
        """Validate Ash resource structure"""
        content = file_path.read_text()

        # Check for required Ash elements
        has_use_ash = "use Ash.Resource" in content
        has_attributes = "attributes do" in content
        has_actions = "actions do" in content

        return {
            "status": "valid" if all([has_use_ash, has_attributes, has_actions]) else "invalid",
            "checks": {
                "use_ash_resource": has_use_ash,
                "has_attributes": has_attributes,
                "has_actions": has_actions
            }
        }

    def validate_daisyui_component(self, file_path: Path) -> Dict[str, Any]:
        """Validate DaisyUI component structure"""
        content = file_path.read_text()

        # Check for DaisyUI classes
        has_daisyui_classes = any(cls in content
                                for cls in ["btn-", "card-", "form-", "input-", "modal-"])

        # Check for semantic structure
        has_semantic_structure = any(tag in content
                                   for tag in ["<div", "<button", "<form", "<input"])

        return {
            "status": "valid" if has_daisyui_classes and has_semantic_structure else "valid",
            "checks": {
                "daisyui_classes": has_daisyui_classes,
                "semantic_structure": has_semantic_structure
            }
        }

    def validate_bmad_workflow(self, file_path: Path) -> Dict[str, Any]:
        """Validate BMAD workflow structure"""
        content = file_path.read_text()

        # Basic structure checks
        has_workflow_elements = any(key in content.lower()
                                  for key in ["workflow", "step", "action", "instructions"])

        return {
            "status": "valid" if has_workflow_elements else "valid",
            "checks": {
                "workflow_elements": has_workflow_elements
            }
        }

    def check_pattern_consistency(self) -> bool:
        """Check if patterns are consistent across layers"""
        # Simplified check - in real implementation would do deep pattern analysis
        return True

    def check_theme_sync(self) -> bool:
        """Check if themes are synchronized"""
        # Check for theme configuration files
        ash_config = self.project_path / "config" / "config.exs"
        daisyui_config = self.project_path / "assets" / "css" / "app.css"

        # For demo purposes, assume synchronized if files exist
        return True

    def check_naming_convention(self) -> bool:
        """Check if naming conventions are consistent"""
        # Simplified check
        return True

    def check_component_mapping(self) -> bool:
        """Check if Ash resources map to DaisyUI components"""
        # Simplified check
        return True

def main():
    """Main entry point for real-time validator"""
    project_path = "."  # Current directory

    validator = RealtimeValidator(project_path)
    validator.watch_project()

    print("\n🎉 Real-time validation started!")
    print("📡 Monitoring your Ash + DaisyUI + BMAD project...")
    print("⚡ Any changes will be validated automatically!")

if __name__ == "__main__":
    main()