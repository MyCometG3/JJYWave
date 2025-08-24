#!/usr/bin/env python3
"""
JJYWave Project Integrity Validator
===================================

Quick validation script to verify the JJYWave Xcode project is not corrupted.
This script checks for the issues that were present in the original corruption.

Usage: python3 validate_project.py

Exit codes:
0 - Project is healthy
1 - Project has integrity issues
"""

import os
import re
import sys
from pathlib import Path

def validate_project(project_root):
    """Validate JJYWave project integrity."""
    print("🔍 JJYWave Project Integrity Validator")
    print("=====================================")
    
    issues = []
    
    # 1. Check project file exists and is readable
    pbxproj_path = project_root / "JJYWave.xcodeproj" / "project.pbxproj"
    if not pbxproj_path.exists():
        issues.append("❌ project.pbxproj missing")
        return issues
    
    try:
        with open(pbxproj_path, 'r') as f:
            pbx_content = f.read()
        print("✅ Project file readable")
    except Exception as e:
        issues.append(f"❌ Cannot read project.pbxproj: {e}")
        return issues
    
    # 2. Check basic PBX structure integrity
    required_sections = [
        "Begin PBXBuildFile section",
        "Begin PBXFileReference section", 
        "Begin PBXNativeTarget section",
        "Begin PBXProject section"
    ]
    
    missing_sections = []
    for section in required_sections:
        if section not in pbx_content:
            missing_sections.append(section)
    
    if missing_sections:
        issues.append(f"❌ Missing project sections: {missing_sections}")
    else:
        print("✅ All required PBX sections present")
    
    # 3. Check file count consistency
    swift_files = list(project_root.glob("**/*.swift"))
    main_swift = [f for f in swift_files if "/Tests/" not in str(f) and "/JJYWaveTests/" not in str(f)]
    test_swift = [f for f in swift_files if "/Tests/" in str(f) or "/JJYWaveTests/" in str(f)]
    
    # Expected file counts (based on current working state)
    expected_main_swift = 17
    expected_test_swift = 20
    
    if len(main_swift) != expected_main_swift:
        issues.append(f"❌ Expected {expected_main_swift} main Swift files, found {len(main_swift)}")
    else:
        print(f"✅ Main Swift files: {len(main_swift)}")
    
    if len(test_swift) != expected_test_swift:
        issues.append(f"❌ Expected {expected_test_swift} test Swift files, found {len(test_swift)}")
    else:
        print(f"✅ Test Swift files: {len(test_swift)}")
    
    # 4. Check key directories exist
    required_dirs = [
        "App",
        "JJYKit/Audio", 
        "JJYKit/Frames",
        "JJYKit/Generator",
        "JJYKit/Services", 
        "JJYKit/Time",
        "Tests",
        "JJYWaveTests"
    ]
    
    missing_dirs = []
    for dir_path in required_dirs:
        if not (project_root / dir_path).exists():
            missing_dirs.append(dir_path)
    
    if missing_dirs:
        issues.append(f"❌ Missing directories: {missing_dirs}")
    else:
        print("✅ All required directories present")
    
    # 5. Check key resource files
    required_files = [
        "Base.lproj/Main.storyboard",
        "Localizable.xcstrings",
        "JJYWave.entitlements",
        "README.md"
    ]
    
    missing_files = []
    for file_path in required_files:
        if not (project_root / file_path).exists():
            missing_files.append(file_path)
    
    if missing_files:
        issues.append(f"❌ Missing resource files: {missing_files}")
    else:
        print("✅ All key resource files present")
    
    # 6. Quick syntax check on critical files
    critical_files = [
        "JJYKit/Generator/JJYAudioGenerator.swift",
        "App/ViewController.swift",
        "App/AppDelegate.swift"
    ]
    
    syntax_issues = []
    for file_path in critical_files:
        full_path = project_root / file_path
        if full_path.exists():
            try:
                with open(full_path, 'r') as f:
                    content = f.read()
                
                # Remove strings and comments for accurate brace counting
                clean_content = re.sub(r'"[^"]*"', '""', content)
                clean_content = re.sub(r"'[^']*'", "''", clean_content)
                clean_content = re.sub(r'//.*', '', clean_content)
                clean_content = re.sub(r'/\*.*?\*/', '', clean_content, flags=re.DOTALL)
                
                if clean_content.count('{') != clean_content.count('}'):
                    syntax_issues.append(f"{file_path}: Unbalanced braces")
                    
            except Exception as e:
                syntax_issues.append(f"{file_path}: Read error - {e}")
    
    if syntax_issues:
        issues.append(f"❌ Syntax issues in critical files: {syntax_issues}")
    else:
        print("✅ Critical files syntax check passed")
    
    return issues

def main():
    project_root = Path.cwd()
    
    # Auto-detect if we're in the right directory
    if not (project_root / "JJYWave.xcodeproj").exists():
        print("❌ Not in JJYWave project directory")
        print("   Please run this script from the JJYWave project root")
        return 1
    
    issues = validate_project(project_root)
    
    print("\n" + "="*50)
    
    if not issues:
        print("🎉 PROJECT VALIDATION PASSED")
        print("✅ No corruption or structural issues detected")
        print("✅ Project is ready for development")
        return 0
    else:
        print("⚠️  PROJECT VALIDATION FAILED")
        print("❌ Issues detected:")
        for issue in issues:
            print(f"   {issue}")
        print("\n💡 Consider comparing with a known good project state")
        return 1

if __name__ == "__main__":
    sys.exit(main())