"""
ZIP Packager for LegacyLink AI
Packages all generated files into a downloadable ZIP archive
"""

import zipfile
import io
from typing import Dict


class ZipPackager:
    """Package generated files into a ZIP archive"""
    
    def create_zip(self, files: Dict[str, str], project_name: str = "generated_project") -> bytes:
        """
        Create a ZIP file containing all generated files
        
        Args:
            files: Dictionary mapping filenames to their content
            project_name: Name of the project directory in the ZIP
            
        Returns:
            ZIP file content as bytes
        """
        # Create an in-memory bytes buffer
        zip_buffer = io.BytesIO()
        
        # Create ZIP file
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
            for filename, content in files.items():
                # Add file to ZIP with project directory prefix
                arcname = f"{project_name}/{filename}"
                zip_file.writestr(arcname, content)
        
        # Get the ZIP file content
        zip_buffer.seek(0)
        return zip_buffer.getvalue()
    
    def get_file_structure(self, files: Dict[str, str]) -> str:
        """
        Generate a text representation of the file structure
        
        Args:
            files: Dictionary mapping filenames to their content
            
        Returns:
            Text representation of file tree
        """
        structure = ["generated_project/"]
        for filename in sorted(files.keys()):
            structure.append(f"├── {filename}")
        
        # Replace last ├── with └──
        if len(structure) > 1:
            structure[-1] = structure[-1].replace("├──", "└──")
        
        return '\n'.join(structure)

# Made with Bob
