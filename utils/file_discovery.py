import os
import re
import logging
from typing import List, Optional, Union

def recursive_file_search(
    base_dir: str, 
    filename_patterns: Union[str, List[str]], 
    max_depth: Optional[int] = None,
    case_sensitive: bool = False
) -> List[str]:
    """
    Recursively search for files matching given patterns in a base directory.
    
    Args:
        base_dir (str): Root directory to start the search from
        filename_patterns (str or List[str]): Filename pattern(s) to match
        max_depth (int, optional): Maximum directory depth to search. 
                                   None means no depth limit.
        case_sensitive (bool): Whether to use case-sensitive matching
    
    Returns:
        List[str]: Full paths of matching files
    """
    # Ensure base_dir is absolute and exists
    base_dir = os.path.abspath(base_dir)
    if not os.path.isdir(base_dir):
        logging.warning(f"Base directory does not exist: {base_dir}")
        return []
    
    # Normalize filename patterns to a list
    if isinstance(filename_patterns, str):
        filename_patterns = [filename_patterns]
    
    # Compile regex patterns
    regex_patterns = []
    for pattern in filename_patterns:
        # Convert glob-style wildcards to regex
        pattern = pattern.replace('.', r'\.')
        pattern = pattern.replace('*', '.*')
        
        # Compile with appropriate case sensitivity
        flag = 0 if case_sensitive else re.IGNORECASE
        regex_patterns.append(re.compile(pattern, flag))
    
    # Store matching files
    matching_files = []
    
    # Walk through directory
    for root, _, files in os.walk(base_dir):
        # Check depth if max_depth is specified
        if max_depth is not None:
            depth = root[len(base_dir):].count(os.sep)
            if depth > max_depth:
                continue
        
        # Check each file against patterns
        for filename in files:
            for pattern in regex_patterns:
                if pattern.search(filename):
                    matching_files.append(os.path.join(root, filename))
                    break  # Stop checking other patterns for this file
    
    return matching_files

def find_forensic_files(
    base_dir: str, 
    file_type: str, 
    max_depth: Optional[int] = None,
    verbose: bool = False
) -> List[str]:
    """
    Find specific types of forensic files within the base directory.
    
    Args:
        base_dir (str): Base directory to start discovery from
        file_type (str): Type of files to find (e.g., 'Amcache', 'Prefetch')
        max_depth (int, optional): Maximum directory depth to search
        verbose (bool): Whether to enable verbose logging
        
    Returns:
        List[str]: List of discovered file paths
    """
    # Logging setup
    logger = logging.getLogger('forensic_file_discovery')
    if verbose:
        logger.setLevel(logging.DEBUG)
    
    # File patterns mapping
    FILE_PATTERNS = {
        'Amcache': [
            '*ssociatedFileEntries*.csv', 
            '*amcache*.csv'
        ],
        'Prefetch': [
            '*prefetch*.csv', 
            '*pf*.csv'
        ],
        'Shimcache': [
            '*shimcache*.csv', 
            '*appcompat*.csv'
        ],
        'MFT': [
            '*_mft*.csv', 
            '*$mft*.csv', 
            '*mftecmd*.csv'
        ],
        'Registry': [
            '*registry*.csv', 
            '*reg*.csv', 
            '*hive*.csv'
        ],
        'EventLogs': [
            '*evt*.csv', 
            '*eventlog*.csv', 
            '*events*.csv'
        ]
        # Add more file type patterns as needed
    }
    
    # Get patterns for the specific file type
    patterns = FILE_PATTERNS.get(file_type, [])
    
    if not patterns:
        logger.warning(f"No patterns defined for file type: {file_type}")
        return []
    
    # Perform recursive search
    matching_files = recursive_file_search(
        base_dir, 
        patterns, 
        max_depth=max_depth,
        case_sensitive=False
    )
    
    if verbose:
        logger.debug(f"Found {len(matching_files)} {file_type} files:")
        for file in matching_files:
            logger.debug(f"  {file}")
    
    return matching_files