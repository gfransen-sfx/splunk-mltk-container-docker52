import subprocess
import csv
import re

def print_status(message):
    print(f"[STATUS] {message}")

# Get a list of all installed packages
print_status("Fetching list of installed packages...")
result = subprocess.run(['pip', 'list'], stdout=subprocess.PIPE, text=True)
installed_packages = result.stdout.splitlines()[2:]  # Skip header lines

print_status(f"Found {len(installed_packages)} packages installed.")

# Prepare the CSV file
with open('package_details.csv', mode='w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(['Package Name', 'Version', 'Requires', 'Required By'])

    for index, package in enumerate(installed_packages, start=1):
        package_name = package.split()[0]
        
        print_status(f"Processing package {index}/{len(installed_packages)}: {package_name}...")

        # Get detailed information about the package
        result = subprocess.run(['pip', 'show', package_name], stdout=subprocess.PIPE, text=True)
        details = result.stdout
        
        # Extract relevant details
        version = re.search(r'^Version: (.+)', details, re.MULTILINE).group(1)
        requires = re.search(r'^Requires: (.*)', details, re.MULTILINE).group(1)
        required_by = re.search(r'^Required-by: (.*)', details, re.MULTILINE).group(1)
        
        # Handle cases where there are no dependencies or dependents
        requires = requires if requires else 'None'
        required_by = required_by if required_by else 'None'
        
        # Write to CSV
        writer.writerow([package_name, version, requires, required_by])

print_status("Package details have been successfully exported to 'package_details.csv'.")
