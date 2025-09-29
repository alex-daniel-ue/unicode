import os

def collect_gd_files(root_dir, output_file):
    """
    Recursively collects and reads .gd files and appends them to one big .txt file,
    ignoring the 'addons' directory at any level.
    Each entry is prepended with a heading containing the file's relative path.

    Args:
        root_dir (str): The path to the root directory to start searching for .gd files.
        output_file (str): The path to the output .txt file.
    """
    with open(output_file, 'w', encoding='utf-8') as outfile:
        for dirpath, dirnames, filenames in os.walk(root_dir):
            # Exclude the 'addons' directory from traversal
            if 'addons' in dirnames:
                dirnames.remove('addons')

            for filename in filenames:
                if filename.endswith('.tscn'):
                    # Construct the full path to the file
                    file_path = os.path.join(dirpath, filename)
                    
                    # Get the path relative to the starting root_dir
                    relative_path = os.path.relpath(file_path, root_dir)
                    
                    # Use the relative path in the heading
                    outfile.write(f"# {relative_path}\n")
                    outfile.write("```\n")
                    try:
                        with open(file_path, 'r', encoding='utf-8') as infile:
                            outfile.write(infile.read())
                    except Exception as e:
                        outfile.write(f"Error reading file: {e}")
                    outfile.write("\n```\n\n")

if __name__ == '__main__':
    # --- Configuration ---
    # Set the starting directory for the search. 
    # Use '.' to search from the directory where the script is located.
    search_directory = '.' 
    
    # Set the name of the output file.
    combined_file = '.combined/combined_tscn_scenes.txt'

    # --- Execution ---
    try:
        collect_gd_files(search_directory, combined_file)
        print(f"Successfully collected all .gd files into '{combined_file}'")
    except Exception as e:
        print(f"An error occurred: {e}")