#!/bin/bash

# Assuming 'tag' is set somewhere in your script
tag="golden-cpu"  # Example tag, this should be dynamically set

# Print the tag being searched for
echo "Searching for tag: $tag"

# Extract the line corresponding to the tag
line=$(grep "^${tag}," tag_mapping.csv | tr -d '\r')

# Print the line extracted from the CSV
echo "Extracted line: '$line'"

# Check if a line was found
if [ "$line" != "" ]; then
    base_image=$(echo $line | cut -d',' -f2 | xargs)
    dockerfile=$(echo $line | cut -d',' -f3 | xargs)
    base_requirements=$(echo $line | cut -d',' -f4 | xargs)
    specific_requirements=$(echo $line | cut -d',' -f5 | xargs)
    runtime=$(echo $line | cut -d',' -f6 | xargs)
    requirements_dockerfile=$(echo $line | cut -d',' -f7 | xargs)
    title=$(echo $line | cut -d',' -f8 | xargs)

    # Print out all extracted values
    echo "Tag: $tag"
    echo "Base Image: '$base_image'"
    echo "Dockerfile: '$dockerfile'"
    echo "Base Requirements File: '$base_requirements'"
    echo "Specific Requirements File: '$specific_requirements'"
    echo "Runtime Options: '$runtime'"
    echo "Requirements Dockerfile: '$requirements_dockerfile'"
    echo "Title: '$title'"
else
    echo "No match found for tag: $tag"
    exit 1
fi

# Assuming the Dockerfile expects ARG to be set
echo "Building Docker image using base image: '$base_image' and Dockerfile: '$dockerfile'"
docker build --build-arg BASE_IMAGE="$base_image" -f "$dockerfile" .
