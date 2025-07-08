import os
import re
import datetime

def parse_luacov_report(file_path):
    coverage_data = {}
    current_file = None
    line_counts = {"covered": 0, "not_covered": 0, "total": 0}
    
    with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            # Look for file headers
            if line.startswith('=============================================================================='):
                file_header = next(f, '').strip()
                if file_header.startswith('=============================================================================='):
                    continue
                
                # Process the previous file if there was one
                if current_file and current_file in coverage_data:
                    coverage_data[current_file]['coverage_pct'] = (
                        (coverage_data[current_file]['covered'] / coverage_data[current_file]['total']) * 100
                        if coverage_data[current_file]['total'] > 0 else 0
                    )
                
                # Filter to include only our project files
                if "TeleportFavorites" in file_header and not file_header.endswith('.lua'):
                    continue
                
                current_file = file_header
                coverage_data[current_file] = {
                    'covered': 0,
                    'not_covered': 0,
                    'total': 0,
                    'coverage_pct': 0
                }
                continue
                
            # Count covered and uncovered lines
            if current_file and current_file in coverage_data:
                # Count covered lines (those with a number at the beginning)
                if re.match(r'^\s*\d+', line):
                    coverage_data[current_file]['covered'] += 1
                    coverage_data[current_file]['total'] += 1
                    line_counts['covered'] += 1
                    line_counts['total'] += 1
                # Count uncovered lines (those with asterisks)
                elif re.match(r'^\s*\*+\d+', line):
                    coverage_data[current_file]['not_covered'] += 1
                    coverage_data[current_file]['total'] += 1
                    line_counts['not_covered'] += 1
                    line_counts['total'] += 1
    
    # Process the last file
    if current_file and current_file in coverage_data:
        coverage_data[current_file]['coverage_pct'] = (
            (coverage_data[current_file]['covered'] / coverage_data[current_file]['total']) * 100
            if coverage_data[current_file]['total'] > 0 else 0
        )
    
    # Calculate overall coverage
    overall_coverage = {
        'covered': line_counts['covered'],
        'not_covered': line_counts['not_covered'],
        'total': line_counts['total'],
        'coverage_pct': (line_counts['covered'] / line_counts['total']) * 100 if line_counts['total'] > 0 else 0
    }
    
    return coverage_data, overall_coverage

def filter_mod_files(coverage_data, mod_prefix="v:\\Fac2orios\\2_Gemini\\mods\\TeleportFavorites"):
    mod_files = {}
    
    for file_path, stats in coverage_data.items():
        if mod_prefix.lower() in file_path.lower():
            # Extract the relative path within the mod
            relative_path = file_path[len(mod_prefix):].lstrip('\\/')
            mod_files[relative_path] = stats
    
    return mod_files

def group_files_by_directory(mod_files):
    directory_stats = {}
    
    for file_path, stats in mod_files.items():
        parts = file_path.split('\\')
        directory = parts[0] if parts else "root"
        
        if directory not in directory_stats:
            directory_stats[directory] = {
                'covered': 0,
                'not_covered': 0,
                'total': 0,
                'files': [],
                'coverage_pct': 0
            }
        
        directory_stats[directory]['covered'] += stats['covered']
        directory_stats[directory]['not_covered'] += stats['not_covered']
        directory_stats[directory]['total'] += stats['total']
        directory_stats[directory]['files'].append((file_path, stats))
    
    # Calculate coverage percentage for each directory
    for directory in directory_stats:
        if directory_stats[directory]['total'] > 0:
            directory_stats[directory]['coverage_pct'] = (
                directory_stats[directory]['covered'] / directory_stats[directory]['total']
            ) * 100
    
    return directory_stats

def format_report(mod_files, directory_stats, overall_coverage):
    now = datetime.datetime.now()
    report = f"# TeleportFavorites Test Coverage Report\n\n"
    report += f"Generated: {now.strftime('%Y-%m-%d %H:%M:%S')}\n\n"
    
    # Overall summary
    report += "## Overall Coverage\n\n"
    report += f"- **Lines Covered**: {overall_coverage['covered']}\n"
    report += f"- **Lines Not Covered**: {overall_coverage['not_covered']}\n"
    report += f"- **Total Lines**: {overall_coverage['total']}\n"
    report += f"- **Coverage Percentage**: {overall_coverage['coverage_pct']:.2f}%\n\n"
    
    # Directory summary
    report += "## Coverage by Directory\n\n"
    report += "| Directory | Lines Covered | Lines Not Covered | Total Lines | Coverage |\n"
    report += "|-----------|---------------|-------------------|-------------|----------|\n"
    
    sorted_directories = sorted(directory_stats.items(), 
                               key=lambda x: x[1]['coverage_pct'], 
                               reverse=True)
    
    for directory, stats in sorted_directories:
        report += f"| {directory} | {stats['covered']} | {stats['not_covered']} | {stats['total']} | {stats['coverage_pct']:.2f}% |\n"
    
    # Detailed file coverage
    report += "\n## Detailed File Coverage\n\n"
    
    for directory, stats in sorted_directories:
        report += f"### {directory}\n\n"
        report += "| File | Lines Covered | Lines Not Covered | Total Lines | Coverage |\n"
        report += "|------|---------------|-------------------|-------------|----------|\n"
        
        # Sort files by coverage percentage (descending)
        sorted_files = sorted(stats['files'], 
                             key=lambda x: x[1]['coverage_pct'], 
                             reverse=True)
        
        for file_path, file_stats in sorted_files:
            file_name = file_path.split('\\')[-1]
            report += f"| {file_name} | {file_stats['covered']} | {file_stats['not_covered']} | {file_stats['total']} | {file_stats['coverage_pct']:.2f}% |\n"
        
        report += "\n"
    
    # Files with low coverage
    report += "## Files with Low Coverage (<70%)\n\n"
    report += "| File | Lines Covered | Lines Not Covered | Total Lines | Coverage |\n"
    report += "|------|---------------|-------------------|-------------|----------|\n"
    
    low_coverage_files = []
    for file_path, stats in mod_files.items():
        if stats['coverage_pct'] < 70 and stats['total'] > 5:  # Only include files with more than 5 lines
            low_coverage_files.append((file_path, stats))
    
    # Sort by coverage percentage (ascending)
    low_coverage_files.sort(key=lambda x: x[1]['coverage_pct'])
    
    for file_path, stats in low_coverage_files:
        report += f"| {file_path} | {stats['covered']} | {stats['not_covered']} | {stats['total']} | {stats['coverage_pct']:.2f}% |\n"
    
    return report

def main():
    report_path = "v:\\Fac2orios\\2_Gemini\\mods\\TeleportFavorites\\luacov.report.out"
    output_path = "v:\\Fac2orios\\2_Gemini\\mods\\TeleportFavorites\\coverage_summary.md"
    
    coverage_data, overall_coverage = parse_luacov_report(report_path)
    mod_files = filter_mod_files(coverage_data)
    directory_stats = group_files_by_directory(mod_files)
    report = format_report(mod_files, directory_stats, overall_coverage)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(f"Coverage report generated at {output_path}")

if __name__ == "__main__":
    main()
