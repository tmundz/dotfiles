#!/bin/bash

# Define the file containing the list of packages
PACKAGE_LIST="packages.txt"

# Check if paru is installed
if ! command -v paru &> /dev/null
then
    echo "paru could not be found, please install paru first."
    exit 1
fi

# Install each package from the list
while IFS= read -r package
do
    # Extract only the package name (before the first space)
    pkg_name=$(echo "$package" | cut -d ' ' -f 1)
    
    # Install the package using paru
    echo "Installing $pkg_name..."
    paru -S --noconfirm "$pkg_name"
done < "$PACKAGE_LIST"

echo "All packages have been installed."

