#!/usr/bin/env python3
"""
Lua Code Line Counter for TeleportFavorites Mod
===============================================
Analyzes all *.lua files in the project (excluding tests) and provides:
- Line count per file (excluding comments and blank lines)
- Files sorted from most to least lines
- Totals per folder
- Grand total across the project

Usage: python .scripts/analyze_lua_lines.py
"""

import os
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple, NamedTuple

class FileAnalysis(NamedTuple):
    """Results of analyzing a single file."""
    path: str
    total_lines: int
    annotation_lines: int
    code_lines: int

def is_annotation_line(line: str) -> bool:
    """
    Check if a line is an annotation (---@param, ---@return, etc.)
    
    Args:
        line: The line to check
        
    Returns:
        True if the line is an annotation, False otherwise
    """
    stripped = line.strip()
    return stripped.startswith('---@')

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

def count_lua_lines(file_path: Path) -> Tuple[int, int]:
    """
    Count lines in a Lua file, separating annotations from regular code.
    
    Args:
        file_path: Path to the Lua file
        
    Returns:
        Tuple of (total_lines, annotation_lines) where total_lines includes annotations
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
            return 0, 0
    except Exception as e:
        print(f"Warning: Could not read {file_path}: {e}")
        return 0, 0
    
    total_lines = 0
    annotation_lines = 0
    in_multiline_comment = False
    
    for line in lines:
        stripped = line.strip()
        
        # Handle multi-line comments --[[ ... ]]
        if '--[[' in stripped and not in_multiline_comment:
            # Check if this is an annotation block (starts with ---@)
            if stripped.startswith('---@') or (stripped.startswith('--[[') and '---@' in stripped):
                # This is an annotation block, count it
                if is_annotation_line(line):
                    annotation_lines += 1
                total_lines += 1
                continue
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
        
        # Check for annotations first (these count as code)
        if is_annotation_line(line):
            annotation_lines += 1
            total_lines += 1
            continue
        
        # Skip regular comments and blank lines
        if is_comment_or_blank_line(line):
            continue
        
        total_lines += 1
    
    return total_lines, annotation_lines

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

def analyze_lua_files(project_root: str) -> Tuple[List[FileAnalysis], Dict[str, Tuple[int, int]], int, int]:
    """
    Analyze all Lua files in the project.
    
    Args:
        project_root: Root directory of the project
        
    Returns:
        Tuple of (file_results, folder_totals, grand_total_lines, grand_total_annotations)
    """
    project_path = Path(project_root)
    file_results = []
    folder_totals = defaultdict(lambda: [0, 0])  # [total_lines, annotation_lines]
    grand_total_lines = 0
    grand_total_annotations = 0
    
    # Find all .lua files
    lua_files = list(project_path.rglob('*.lua'))
    
    for lua_file in lua_files:
        # Skip if file should be excluded
        if should_exclude_file(lua_file, project_path):
            continue
        
        # Count lines in the file
        total_lines, annotation_lines = count_lua_lines(lua_file)
        code_lines = total_lines - annotation_lines
        
        # Get relative path for display
        relative_path = lua_file.relative_to(project_path)
        relative_path_str = str(relative_path).replace('\\', '/')
        
        # Add to results
        file_results.append(FileAnalysis(
            path=relative_path_str,
            total_lines=total_lines,
            annotation_lines=annotation_lines,
            code_lines=code_lines
        ))
        
        # Add to folder totals
        folder = relative_path.parent if relative_path.parent != Path('.') else Path('root')
        folder_key = str(folder).replace('\\', '/') if str(folder) != '.' else 'root'
        folder_totals[folder_key][0] += total_lines
        folder_totals[folder_key][1] += annotation_lines
        
        # Add to grand totals
        grand_total_lines += total_lines
        grand_total_annotations += annotation_lines
    
    # Sort files by total line count (descending)
    file_results.sort(key=lambda x: x.total_lines, reverse=True)
    
    # Convert folder_totals to regular dict with tuples
    folder_totals_dict = {k: (v[0], v[1]) for k, v in folder_totals.items()}
    
    return file_results, folder_totals_dict, grand_total_lines, grand_total_annotations

def print_analysis_report(file_results: List[FileAnalysis], 
                         folder_totals: Dict[str, Tuple[int, int]], 
                         grand_total_lines: int,
                         grand_total_annotations: int):
    """
    Print the analysis report.
    
    Args:
        file_results: List of FileAnalysis objects
        folder_totals: Dictionary of folder totals (total_lines, annotation_lines)
        grand_total_lines: Total lines across all files
        grand_total_annotations: Total annotation lines across all files
    """
    grand_total_code = grand_total_lines - grand_total_annotations
    annotation_percentage = (grand_total_annotations / grand_total_lines * 100) if grand_total_lines > 0 else 0
    
    print("TeleportFavorites Mod - Lua Code Analysis")
    print("=" * 50)
    print(f"Total files analyzed: {len(file_results)}")
    print(f"Grand total lines: {grand_total_lines:,}")
    print(f"  - Code lines: {grand_total_code:,}")
    print(f"  - Annotation lines: {grand_total_annotations:,} ({annotation_percentage:.1f}%)")
    print()
    
    # Folder totals first (sorted by total lines)
    print("TOTALS BY FOLDER (Most to Least)")
    print("-" * 50)
    sorted_folders = sorted(folder_totals.items(), key=lambda x: x[1][0], reverse=True)
    for folder, (total_lines, annotation_lines) in sorted_folders:
        code_lines = total_lines - annotation_lines
        ann_pct = (annotation_lines / total_lines * 100) if total_lines > 0 else 0
        print(f"{total_lines:5,} lines ({code_lines:,} code, {annotation_lines:,} annotations {ann_pct:.1f}%) - {folder}/")
    
    print()
    
    # Files by line count (most to least)
    print("FILES BY LINE COUNT (Most to Least)")
    print("-" * 60)
    for file_analysis in file_results:
        ann_pct = (file_analysis.annotation_lines / file_analysis.total_lines * 100) if file_analysis.total_lines > 0 else 0
        print(f"{file_analysis.total_lines:5,} lines ({file_analysis.code_lines:,} code, {file_analysis.annotation_lines:,} ann {ann_pct:4.1f}%) - {file_analysis.path}")
    
    print()
    print(f"GRAND TOTAL: {grand_total_lines:,} lines of Lua")
    print(f"  Total files: {len(file_results)}")
    print(f"  Code lines: {grand_total_code:,}")
    print(f"  Annotation lines: {grand_total_annotations:,} ({annotation_percentage:.1f}%)")
    print("(Excluding regular comments and blank lines)")
    print("(Excluding test files)")
    print("(Annotations are lines starting with ---@param, ---@return, etc.)")

def main():
    """Main function to run the analysis."""
    # Get the directory where this script is located and go up one level to project root
    script_dir = Path(__file__).parent
    project_root = str(script_dir.parent)  # Go up one level from .scripts to mod root
    
    print(f"Analyzing Lua files in: {project_root}")
    print("Excluding: comments and blank lines (but keeping annotations like ---@param)")
    print("Excluding: test files")
    print()
    
    try:
        file_results, folder_totals, grand_total_lines, grand_total_annotations = analyze_lua_files(project_root)
        print_analysis_report(file_results, folder_totals, grand_total_lines, grand_total_annotations)
        
    except Exception as e:
        print(f"Error during analysis: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
