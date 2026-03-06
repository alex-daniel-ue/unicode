import os

def generate_file_tree(root_dir, ignore_dirs, ignore_extensions, script_dir):
    """
    Generates a formatted file tree string for the project directory.
    Skips ignored directories, ignored extensions, and files in the script's own directory.
    """
    tree_lines = []
    root_display = os.path.basename(os.path.abspath(root_dir)) or root_dir
    tree_lines.append(f"{root_display}/")

    def _walk_tree(current_dir, prefix=""):
        entries = sorted(os.listdir(current_dir))
        current_abs = os.path.abspath(current_dir)

        dirs = [e for e in entries
                if os.path.isdir(os.path.join(current_dir, e))
                and e not in ignore_dirs]

        # Exclude files in the script's own directory and files with ignored extensions
        if current_abs == script_dir:
            files = []
        else:
            files = [e for e in entries
                     if os.path.isfile(os.path.join(current_dir, e))
                     and os.path.splitext(e)[1] not in ignore_extensions]

        all_entries = dirs + files

        for i, entry in enumerate(all_entries):
            is_last = (i == len(all_entries) - 1)
            connector = "└── " if is_last else "├── "
            full_path = os.path.join(current_dir, entry)

            if os.path.isdir(full_path):
                tree_lines.append(f"{prefix}{connector}{entry}/")
                extension = "    " if is_last else "│   "
                _walk_tree(full_path, prefix + extension)
            else:
                tree_lines.append(f"{prefix}{connector}{entry}")

    _walk_tree(root_dir)
    return "\n".join(tree_lines)


def collect_project_files(root_dir, output_dir):
    """
    Recursively collects .gd, .tscn, .tres, and .py files.
    1. Generates a project file tree.
    2. Writes them to separate combined files in the output directory.
    3. Collates everything into one master file, tree first.
    Ignores 'addons', '.git', '.import' directories,
    .uid/.import file extensions, and files in the script's own directory.
    """

    ignore_dirs = ['addons', '.git', '.import', '.combined', '.godot', '.venv']
    ignore_extensions = {'.uid', '.import'}
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Configuration: Extension -> (Output Filename, Markdown Language Identifier)
    file_types = {
        '.gd':   ('combined_gd_scripts.txt', 'gdscript'),
        '.tscn': ('combined_tscn_scenes.txt', 'xml'),
        '.tres': ('combined_tres_rsrcs.txt', 'text'),
        '.py':   ('combined_py_scripts.txt', 'python'),
    }

    # Configuration: Filenames
    tree_filename = 'project_file_tree.txt'
    master_filename = 'all_project_files.txt'

    # 1. Create Output Directory automatically
    if not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir)
            print(f"Created directory: {output_dir}")
        except OSError as e:
            print(f"Error creating directory {output_dir}: {e}")
            return

    # 2. Generate and write the file tree
    print("Generating project file tree...")
    file_tree = generate_file_tree(root_dir, ignore_dirs, ignore_extensions, script_dir)
    tree_path = os.path.join(output_dir, tree_filename)
    try:
        with open(tree_path, 'w', encoding='utf-8') as f:
            f.write(file_tree)
    except Exception as e:
        print(f"Error writing file tree: {e}")

    # 3. Open file handles for all content output files
    open_files = {}
    try:
        for ext, (fname, _) in file_types.items():
            full_path = os.path.join(output_dir, fname)
            open_files[ext] = open(full_path, 'w', encoding='utf-8')

        # 4. Walk the directory tree once
        for dirpath, dirnames, filenames in os.walk(root_dir):
            dirnames[:] = [d for d in dirnames if d not in ignore_dirs]

            # Skip files that live in the same directory as this script
            if os.path.abspath(dirpath) == script_dir:
                continue

            for filename in filenames:
                _, ext = os.path.splitext(filename)

                # Skip ignored extensions
                if ext in ignore_extensions:
                    continue

                if ext in file_types:
                    file_path = os.path.join(dirpath, filename)
                    relative_path = os.path.relpath(file_path, root_dir)

                    out_handle = open_files[ext]
                    lang_tag = file_types[ext][1]

                    out_handle.write(f"# {relative_path}\n")
                    out_handle.write(f"```{lang_tag}\n")

                    try:
                        with open(file_path, 'r', encoding='utf-8') as infile:
                            out_handle.write(infile.read())
                    except UnicodeDecodeError:
                        out_handle.write(f"[ERROR: File is not UTF-8 encoded]\n")
                    except Exception as e:
                        out_handle.write(f"[ERROR reading file: {e}]\n")

                    out_handle.write("\n```\n\n")

    except Exception as e:
        print(f"Critical Error: {e}")
    finally:
        for handle in open_files.values():
            handle.close()

    # 5. Collate all generated files into one master file, tree first
    print(f"Collating files into {master_filename}...")
    master_path = os.path.join(output_dir, master_filename)

    try:
        with open(master_path, 'w', encoding='utf-8') as outfile:
            # --- File Tree Section (always first) ---
            outfile.write(f"{'='*50}\n")
            outfile.write(f"SECTION: Project File Structure\n")
            outfile.write(f"{'='*50}\n\n")
            outfile.write("```\n")
            outfile.write(file_tree)
            outfile.write("\n```\n\n\n")

            # --- Content Sections ---
            for ext, (fname, _) in file_types.items():
                part_path = os.path.join(output_dir, fname)

                if os.path.exists(part_path):
                    outfile.write(f"{'='*50}\n")
                    outfile.write(f"SECTION: {fname}\n")
                    outfile.write(f"{'='*50}\n\n")

                    with open(part_path, 'r', encoding='utf-8') as infile:
                        outfile.write(infile.read())

                    outfile.write("\n\n")

        print("Processing and collation complete.")

    except Exception as e:
        print(f"Error creating master file: {e}")


if __name__ == '__main__':
    search_directory = '.'
    output_directory = '.combined'

    collect_project_files(search_directory, output_directory)