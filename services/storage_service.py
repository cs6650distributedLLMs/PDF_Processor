import os
from werkzeug.utils import secure_filename


def save_file(file_obj, folder, filename=None):
    """
    Save a file to the specified folder

    Args:
        file_obj: Flask file object
        folder (str): Target folder path
        filename (str, optional): Filename to use. If None, uses the original filename.

    Returns:
        str: Full path to the saved file
    """
    # Create folder if it doesn't exist
    os.makedirs(folder, exist_ok=True)

    # Use provided filename or secure the original one
    if filename is None:
        filename = secure_filename(file_obj.filename)
    else:
        filename = secure_filename(filename)

    # Generate full path
    file_path = os.path.join(folder, filename)

    # Save the file
    file_obj.save(file_path)

    return file_path


def get_file_path(folder, filename):
    """
    Get the full path for a file

    Args:
        folder (str): Folder path
        filename (str): Filename

    Returns:
        str: Full path to the file
    """
    return os.path.join(folder, secure_filename(filename))


def delete_file(file_path):
    """
    Delete a file if it exists

    Args:
        file_path (str): Path to the file to delete

    Returns:
        bool: True if deleted, False if file not found
    """
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            return True
        return False
    except Exception as e:
        print(f"Error deleting file {file_path}: {e}")
        return False


def delete_folder_contents(folder):
    """
    Delete all files in a folder

    Args:
        folder (str): Path to the folder

    Returns:
        int: Number of files deleted
    """
    count = 0
    try:
        if os.path.exists(folder):
            for filename in os.listdir(folder):
                file_path = os.path.join(folder, filename)
                if os.path.isfile(file_path):
                    os.remove(file_path)
                    count += 1
    except Exception as e:
        print(f"Error deleting folder contents {folder}: {e}")

    return count
