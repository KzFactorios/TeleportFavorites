"""
Generate a formatted coverage report from luacov.report.out
"""

import os
import re
import sys
from datetime import datetime

def extract_module_coverage(content):
    """Extract coverage information from the luacov report"""
    modules = {}
    current_module = None
    in_module_section = False
    covered_lines = 0
    total_lines = 0
    
    # Process line by line
    lines = content.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Module header
        if line.startswith('='*70):
            # Save previous module
            if current_module is not None:
                modules[current_module] = {
                    'covered': covered_lines,
                    'total': total_lines,
                    'coverage': (covered_lines / total_lines * 100) if total_lines > 0 else 0
                }
            
            # Get next module name (next line)
            i += 1
            if i < len(lines) and not lines[i].startswith('='*70):
                current_module = lines[i]
                covered_lines = 0
                total_lines = 0
                in_module_section = True
            else:
                current_module = None
                in_module_section = False
        
        # Count covered lines (starts with number)
        elif in_module_section and re.match(r'^\s*\d+\s', line):
            covered_lines += 1
            total_lines += 1
        
        # Count uncovered lines (starts with asterisks)
        elif in_module_section and re.match(r'^\s*\*+\d+\s', line):
            total_lines += 1
            
        i += 1
    
    # Add the last module
    if current_module is not None and in_module_section:
        modules[current_module] = {
            'covered': covered_lines,
            'total': total_lines,
            'coverage': (covered_lines / total_lines * 100) if total_lines > 0 else 0
        }
    
    return modules

def filter_project_modules(modules):
    """Filter to include only TeleportFavorites modules"""
    project_modules = {}
    total_covered = 0
    total_lines = 0
    
    for module_path, stats in modules.items():
        if "TeleportFavorites" in module_path:
            module_name = module_path.replace('\\', '/').split('TeleportFavorites/')[-1] if 'TeleportFavorites' in module_path else module_path
            project_modules[module_name] = stats
            total_covered += stats['covered']
            total_lines += stats['total']
    
    return project_modules, total_covered, total_lines

def generate_coverage_report(modules, total_covered, total_lines):
    """Generate formatted coverage report"""
    report = []
    
    # Generate header
    report.append("TeleportFavorites Test Coverage Report")
    report.append("=" * 40)
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append(f"Overall Coverage: {total_covered}/{total_lines} lines ({total_covered/total_lines*100:.2f}%)\n")
    
    # Group modules by type
    core_modules = {}
    gui_modules = {}
    prototype_modules = {}
    other_modules = {}
    
    for path, stats in modules.items():
        if path.startswith("core/"):
            core_modules[path] = stats
        elif path.startswith("gui/"):
            gui_modules[path] = stats
        elif path.startswith("prototypes/"):
            prototype_modules[path] = stats
        else:
            other_modules[path] = stats
    
    # Format modules by section
    def format_section(name, modules_dict):
        if not modules_dict:
            return []
        
        section = []
        section.append(f"\n{name}")
        section.append("-" * len(name))
        
        # Sort by coverage percentage (ascending)
        sorted_modules = sorted(modules_dict.items(), key=lambda x: x[1]['coverage'])
        
        for path, stats in sorted_modules:
            coverage_pct = stats['coverage']
            color = ""
            if coverage_pct < 50:
                color = "LOW"
            elif coverage_pct < 80:
                color = "MED"
            else:
                color = "HIGH"
                
            section.append(f"{path}: {stats['covered']}/{stats['total']} lines ({coverage_pct:.2f}%) {color}")
        
        return section
    
    # Add each section
    report.extend(format_section("Core Modules", core_modules))
    report.extend(format_section("GUI Modules", gui_modules))
    report.extend(format_section("Prototype Modules", prototype_modules))
    report.extend(format_section("Other Modules", other_modules))
    
    return "\n".join(report)

def main():
    report_path = "luacov.report.out"
    
    # Check if file exists
    if not os.path.exists(report_path):
        print(f"Error: {report_path} not found!")
        return 1
    
    # Read the report file
    try:
        with open(report_path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {report_path}: {e}")
        return 1
    
    # Process the report
    try:
        modules = extract_module_coverage(content)
        project_modules, total_covered, total_lines = filter_project_modules(modules)
        report = generate_coverage_report(project_modules, total_covered, total_lines)
        
        # Output report
        with open("coverage_summary.txt", "w") as f:
            f.write(report)
            
        print(report)
        print(f"\nReport saved to coverage_summary.txt")
        
    except Exception as e:
        print(f"Error processing report: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
