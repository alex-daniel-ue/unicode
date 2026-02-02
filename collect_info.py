import os

def collect_project_files(root_dir, output_dir):
    """
    Recursively collects .gd, .tscn, and .tres files.
    1. Writes them to separate combined files in the output directory.
    2. Collates those three files into one master file.
    Ignores 'addons', '.git', and '.import' directories.
    """
    
    # Configuration: Extension -> (Output Filename, Markdown Language Identifier)
    file_types = {
        '.gd':   ('combined_gd_scripts.txt', 'gdscript'),
        '.tscn': ('combined_tscn_scenes.txt', 'xml'), # or 'ini', tscn is ini-like
        '.tres': ('combined_tres_rsrcs.txt', 'text'),
    }
    
    # Configuration: Master output file
    master_filename = 'all_project_files.txt'

    # 1. Create Output Directory automatically
    if not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir)
            print(f"Created directory: {output_dir}")
        except OSError as e:
            print(f"Error creating directory {output_dir}: {e}")
            return

    # 2. Open file handles for all output files
    open_files = {}
    try:
        for ext, (fname, _) in file_types.items():
            full_path = os.path.join(output_dir, fname)
            open_files[ext] = open(full_path, 'w', encoding='utf-8')

        # 3. Walk the directory tree once
        for dirpath, dirnames, filenames in os.walk(root_dir):
            # Modify dirnames in-place to exclude unwanted folders
            ignore_dirs = ['addons', '.git', '.import', '.combined']
            dirnames[:] = [d for d in dirnames if d not in ignore_dirs]

            for filename in filenames:
                _, ext = os.path.splitext(filename)
                
                if ext in file_types:
                    file_path = os.path.join(dirpath, filename)
                    relative_path = os.path.relpath(file_path, root_dir)
                    
                    # Get the corresponding file handle and language tag
                    out_handle = open_files[ext]
                    lang_tag = file_types[ext][1]

                    # Write Header
                    out_handle.write(f"# {relative_path}\n")
                    out_handle.write(f"```{lang_tag}\n")
                    
                    # Write Content
                    try:
                        with open(file_path, 'r', encoding='utf-8') as infile:
                            out_handle.write(infile.read())
                    except UnicodeDecodeError:
                        out_handle.write(f"[ERROR: File is not UTF-8 encoded]\n")
                    except Exception as e:
                        out_handle.write(f"[ERROR reading file: {e}]\n")
                    
                    # Write Footer
                    out_handle.write("\n```\n\n")

    except Exception as e:
        print(f"Critical Error: {e}")
    finally:
        # 4. Clean up: Close all open individual output files
        for handle in open_files.values():
            handle.close()

    # 5. Collate all generated files into one master file
    print(f"Collating files into {master_filename}...")
    master_path = os.path.join(output_dir, master_filename)
    
    try:
        with open(master_path, 'w', encoding='utf-8') as outfile:
            # Iterate through the file types in order
            for ext, (fname, _) in file_types.items():
                part_path = os.path.join(output_dir, fname)
                
                if os.path.exists(part_path):
                    # Write a Section Header for clarity
                    outfile.write(f"{'='*50}\n")
                    outfile.write(f"SECTION: {fname}\n")
                    outfile.write(f"{'='*50}\n\n")
                    
                    # Read the individual file and write to master
                    with open(part_path, 'r', encoding='utf-8') as infile:
                        outfile.write(infile.read())
                    
                    outfile.write("\n\n")
        
        print("Processing and collation complete.")
        
    except Exception as e:
        print(f"Error creating master file: {e}")

if __name__ == '__main__':
    # Configuration
    search_directory = '.'
    output_directory = '.combined'

    collect_project_files(search_directory, output_directory)