#!/usr/bin/env python3
"""
Lua Code Line Counter for TeleportFavorites Mod
===============================================
Analyzes all *.lua files in the project (excluding tests) and provides:
- Line count per file (excluding comments and blank lines)
- Files sorted from most to least lines
- Totals per folder
- Grand total across the project

Usage: python py_scripts/analyze_lua_lines.py
"""

import os
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple

def is_comment_or_blank_line(line: str) -> bool:
    """
    Determine if a line is a comment or blank line.
    Excludes annotation comments (---@param, ---@return, etc.)
    
    Args:
        line: The line to check
        
    Returns:
        True if the line is a comment or blank, False otherwise
    """
    stripped = line.strip()
    
    # Blank line
    if not stripped:
        return True
    
    # Check for annotations (keep these as code lines)
    if stripped.startswith('---@'):
        return False
    
    # Single line comment starting with --
    if stripped.startswith('--'):
        return True
    
    return False

def count_lua_lines(file_path: Path) -> int:
    """
    Count non-comment, non-blank lines in a Lua file.
    
    Args:
        file_path: Path to the Lua file
        
    Returns:
        Number of code lines
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except UnicodeDecodeError:
        # Try with different encoding if UTF-8 fails
        try:
            with open(file_path, 'r', encoding='latin-1') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"Warning: Could not read {file_path}: {e}")
            return 0
    except Exception as e:
        print(f"Warning: Could not read {file_path}: {e}")
        return 0
    
    code_lines = 0
    in_multiline_comment = False
    
    for line in lines:
        stripped = line.strip()
        
        # Handle multi-line comments --[[ ... ]]
        if '--[[' in stripped and not in_multiline_comment:
            # Check if this is an annotation block (starts with ---@)
            if stripped.startswith('---@') or (stripped.startswith('--[[') and '---@' in stripped):
                # This is an annotation block, don't skip it
                pass
            else:
                # Check if comment starts and ends on same line
                if ']]' in stripped and stripped.index(']]') > stripped.index('--[['):
                    # Single line block comment - treat as comment
                    continue
                else:
                    # Start of multi-line comment
                    in_multiline_comment = True
                    continue
        
        if in_multiline_comment:
            if ']]' in stripped:
                in_multiline_comment = False
            continue
        
        # Skip regular comments and blank lines
        if is_comment_or_blank_line(line):
            continue
        
        code_lines += 1
    
    return code_lines

def should_exclude_file(file_path: Path, project_root: Path) -> bool:
    """
    Determine if a file should be excluded from analysis.
    
    Args:
        file_path: Path to the file
        project_root: Root directory of the project
        
    Returns:
        True if file should be excluded, False otherwise
    """
    relative_path = file_path.relative_to(project_root)
    path_parts = relative_path.parts
    
    # Exclude test directories and files
    test_indicators = ['test', 'tests', 'spec', 'specs']
    
    for part in path_parts:
        if part.lower() in test_indicators:
            return True
    
    # Exclude specific test files by name pattern
    filename = file_path.name.lower()
    if any(indicator in filename for indicator in ['test_', '_test', 'spec_', '_spec']):
        return True
    
    return False

def analyze_lua_files(project_root: str) -> Tuple[List[Tuple[str, int]], Dict[str, int], int]:
    """
    Analyze all Lua files in the project.
    
    Args:
        project_root: Root directory of the project
        
    Returns:
        Tuple of (file_results, folder_totals, grand_total)
    """
    project_path = Path(project_root)
    file_results = []
    folder_totals = defaultdict(int)
    grand_total = 0
    
    # Find all .lua files
    lua_files = list(project_path.rglob('*.lua'))
    
    for lua_file in lua_files:
        # Skip if file should be excluded
        if should_exclude_file(lua_file, project_path):
            continue
        
        # Count lines in the file
        line_count = count_lua_lines(lua_file)
        
        # Get relative path for display
        relative_path = lua_file.relative_to(project_path)
        relative_path_str = str(relative_path).replace('\\', '/')
        
        # Add to results
        file_results.append((relative_path_str, line_count))
        
        # Add to folder totals
        folder = relative_path.parent if relative_path.parent != Path('.') else Path('root')
        folder_key = str(folder).replace('\\', '/') if str(folder) != '.' else 'root'
        folder_totals[folder_key] += line_count
        
        # Add to grand total
        grand_total += line_count
    
    # Sort files by line count (descending)
    file_results.sort(key=lambda x: x[1], reverse=True)
    
    return file_results, dict(folder_totals), grand_total

def print_analysis_report(file_results: List[Tuple[str, int]], 
                         folder_totals: Dict[str, int], 
                         grand_total: int):
    """
    Print the analysis report.
    
    Args:
        file_results: List of (file_path, line_count) tuples
        folder_totals: Dictionary of folder totals
        grand_total: Total lines across all files
    """
    print("TeleportFavorites Mod - Lua Code Analysis")
    print("=" * 50)
    print(f"Total files analyzed: {len(file_results)}")
    print(f"Grand total lines of code: {grand_total:,}")
    print()
    
    # Folder totals first (sorted by total lines)
    print("TOTALS BY FOLDER (Most to Least)")
    print("-" * 40)
    sorted_folders = sorted(folder_totals.items(), key=lambda x: x[1], reverse=True)
    for folder, total in sorted_folders:
        print(f"{total:5,} lines - {folder}/")
    
    print()
    
    # Files by line count (most to least)
    print("FILES BY LINE COUNT (Most to Least)")
    print("-" * 50)
    for file_path, line_count in file_results:
        print(f"{line_count:5,} lines - {file_path}")
    
    print()
    print(f"GRAND TOTAL: {grand_total:,} lines of Lua code")
    print("(Excluding comments and blank lines, but including annotations like ---@param, ---@return, etc.)")
    print("(Excluding test files)")

def main():
    """Main function to run the analysis."""
    # Get the directory where this script is located and go up one level to project root
    script_dir = Path(__file__).parent
    project_root = str(script_dir.parent)  # Go up one level from py_scripts to mod root
    
    print(f"Analyzing Lua files in: {project_root}")
    print("Excluding: comments and blank lines (but keeping annotations like ---@param)")
    print("Excluding: test files")
    print()
    
    try:
        file_results, folder_totals, grand_total = analyze_lua_files(project_root)
        print_analysis_report(file_results, folder_totals, grand_total)
        
    except Exception as e:
        print(f"Error during analysis: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
