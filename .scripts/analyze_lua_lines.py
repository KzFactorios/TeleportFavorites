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

def count_lua_lines_and_error_log_lines(file_path: Path) -> Tuple[int, int, int, int]:
    """
    Count lines in a Lua file, separating annotations from regular code, and count error log statement lines (multi-line aware).
    Returns (total_lines, annotation_lines, code_lines, error_log_lines)
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except UnicodeDecodeError:
        try:
            with open(file_path, 'r', encoding='latin-1') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"Warning: Could not read {file_path}: {e}")
            return 0, 0, 0, 0
    except Exception as e:
        print(f"Warning: Could not read {file_path}: {e}")
        return 0, 0, 0, 0

    total_lines = 0
    annotation_lines = 0
    code_lines = 0
    error_log_lines = 0
    in_multiline_comment = False
    in_error_log = False
    error_log_paren_depth = 0
    error_log_start_regex = re.compile(r'\b(log|error|PlayerHelpers\.safe_player_print|PlayerHelpers\.error|PlayerHelpers\.log|ErrorHandler\.warn_log|ErrorHandler\.debug_log)\s*\(')

    for line in lines:
        stripped = line.strip()

        # Handle multi-line comments --[[ ... ]]
        if '--[[' in stripped and not in_multiline_comment:
            if stripped.startswith('---@') or (stripped.startswith('--[[') and '---@' in stripped):
                if is_annotation_line(line):
                    annotation_lines += 1
                total_lines += 1
                continue
            else:
                if ']]' in stripped and stripped.index(']]') > stripped.index('--[['):
                    continue
                else:
                    in_multiline_comment = True
                    continue

        if in_multiline_comment:
            if ']]' in stripped:
                in_multiline_comment = False
            continue

        if is_annotation_line(line):
            annotation_lines += 1
            total_lines += 1
            continue

        if is_comment_or_blank_line(line):
            continue

        # Error log detection (multi-line aware)
        if not in_error_log:
            if error_log_start_regex.search(stripped):
                in_error_log = True
                error_log_paren_depth = stripped.count('(') - stripped.count(')')
                error_log_lines += 1
                total_lines += 1
                if error_log_paren_depth <= 0:
                    in_error_log = False
                continue
        else:
            error_log_paren_depth += stripped.count('(') - stripped.count(')')
            error_log_lines += 1
            total_lines += 1
            if error_log_paren_depth <= 0:
                in_error_log = False
            continue

        total_lines += 1
        code_lines += 1

    return total_lines, annotation_lines, code_lines, error_log_lines

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
    
    # Exclude development/tooling files in project root
    if len(path_parts) == 1:  # Files in project root
        filename = file_path.name.lower()
        if filename in ['.test.lua', 'test.lua', '.test.ps1', 'test.ps1', '.test.bat', 'test.bat']:
            return True
    
    # Exclude factorio.emmy.lua (type definitions, not production code)
    if filename == 'factorio.emmy.lua':
        return True
    
    return False

def analyze_lua_files(project_root: str) -> Tuple[List[FileAnalysis], Dict[str, Tuple[int, int]], int, int, int]:
    """
    Analyze all Lua files in the project, excluding error log statement lines from code lines, and count error log lines.
    Returns (file_results, folder_totals, grand_total_lines, grand_total_annotations, grand_total_error_log_lines)
    """
    project_path = Path(project_root)
    file_results = []
    folder_totals = defaultdict(lambda: [0, 0])  # [total_lines, annotation_lines]
    grand_total_lines = 0
    grand_total_annotations = 0
    grand_total_code_lines = 0
    grand_total_error_log_lines = 0

    lua_files = list(project_path.rglob('*.lua'))

    for lua_file in lua_files:
        if should_exclude_file(lua_file, project_path):
            continue

        total_lines, annotation_lines, code_lines, error_log_lines = count_lua_lines_and_error_log_lines(lua_file)

        relative_path = lua_file.relative_to(project_path)
        relative_path_str = str(relative_path).replace('\\', '/')

        file_results.append(FileAnalysis(
            path=relative_path_str,
            total_lines=total_lines,
            annotation_lines=annotation_lines,
            code_lines=code_lines
        ))

        folder = relative_path.parent if relative_path.parent != Path('.') else Path('root')
        folder_key = str(folder).replace('\\', '/') if str(folder) != '.' else 'root'
        folder_totals[folder_key][0] += total_lines
        folder_totals[folder_key][1] += annotation_lines

        grand_total_lines += total_lines
        grand_total_annotations += annotation_lines
        grand_total_code_lines += code_lines
        grand_total_error_log_lines += error_log_lines

    file_results.sort(key=lambda x: x.total_lines, reverse=True)
    folder_totals_dict = {k: (v[0], v[1]) for k, v in folder_totals.items()}

    return file_results, folder_totals_dict, grand_total_lines, grand_total_annotations, grand_total_code_lines, grand_total_error_log_lines

def print_analysis_report(file_results: List[FileAnalysis], 
                         folder_totals: Dict[str, Tuple[int, int]], 
                         grand_total_lines: int,
                         grand_total_annotations: int,
                         grand_total_code_lines: int,
                         grand_total_error_log_lines: int):
    """
    Print the analysis report, including error log line count.
    """
    annotation_percentage = (grand_total_annotations / grand_total_lines * 100) if grand_total_lines > 0 else 0
    print("TeleportFavorites Mod - Lua Code Analysis")
    print("=" * 50)
    print(f"Total files analyzed: {len(file_results)}")
    print(f"Grand total lines: {grand_total_lines:,}")
    print(f"  - Code lines: {grand_total_code_lines:,}")
    print(f"  - Annotation lines: {grand_total_annotations:,} ({annotation_percentage:.1f}%)")
    print(f"  - Error log lines: {grand_total_error_log_lines:,}")
    print()
    print("TOTALS BY FOLDER (Most to Least)")
    print("-" * 50)
    sorted_folders = sorted(folder_totals.items(), key=lambda x: x[1][0], reverse=True)
    for folder, (total_lines, annotation_lines) in sorted_folders:
        code_lines = total_lines - annotation_lines
        ann_pct = (annotation_lines / total_lines * 100) if total_lines > 0 else 0
        print(f"{total_lines:5,} lines ({code_lines:,} code, {annotation_lines:,} annotations {ann_pct:.1f}%) - {folder}/")
    print()
    print("FILES BY LINE COUNT (Most to Least)")
    print("-" * 60)
    for file_analysis in file_results:
        ann_pct = (file_analysis.annotation_lines / file_analysis.total_lines * 100) if file_analysis.total_lines > 0 else 0
        print(f"{file_analysis.total_lines:5,} lines ({file_analysis.code_lines:,} code, {file_analysis.annotation_lines:,} ann {ann_pct:4.1f}%) - {file_analysis.path}")
    print()
    print(f"GRAND TOTAL: {grand_total_lines:,} lines of Lua")
    print(f"  Total files: {len(file_results)}")
    print(f"  Code lines: {grand_total_code_lines:,}")
    print(f"  Annotation lines: {grand_total_annotations:,} ({annotation_percentage:.1f}%)")
    print(f"  Error log lines: {grand_total_error_log_lines:,}")
    print("(Excluding regular comments and blank lines)")
    print("(Excluding test files, development tools, and factorio.emmy.lua)")
    print("(Annotations are lines starting with ---@param, ---@return, etc.)")

def main():
    """Main function to run the analysis."""
    script_dir = Path(__file__).parent
    project_root = str(script_dir.parent)
    print(f"Analyzing Lua files in: {project_root}")
    print("Excluding: comments and blank lines (but keeping annotations like ---@param)")
    print("Excluding: test files, development tools (.test.* files), and factorio.emmy.lua")
    print()
    try:
        file_results, folder_totals, grand_total_lines, grand_total_annotations, grand_total_code_lines, grand_total_error_log_lines = analyze_lua_files(project_root)
        print_analysis_report(file_results, folder_totals, grand_total_lines, grand_total_annotations, grand_total_code_lines, grand_total_error_log_lines)
    except Exception as e:
        print(f"Error during analysis: {e}")
        return 1
    return 0

if __name__ == "__main__":
    exit(main())
