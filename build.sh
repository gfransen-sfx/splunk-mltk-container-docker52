#!/bin/bash
echo '__________________________________________________________________________________________________________________'
echo ' ________  ________  ___       ___  ___  ________   ___  __            ________  ________  ________  ___          '
echo '|\   ____\|\   __  \|\  \     |\  \|\  \|\   ___  \|\  \|\  \         |\   ___ \|\   ____\|\   ___ \|\  \         '
echo '\ \  \___|\ \  \|\  \ \  \    \ \  \\\  \ \  \\ \  \ \  \/  /|_       \ \  \_|\ \ \  \___|\ \  \_|\ \ \  \        '
echo ' \ \_____  \ \   ____\ \  \    \ \  \\\  \ \  \\ \  \ \   ___  \       \ \  \ \\ \ \_____  \ \  \ \\ \ \  \       '
echo '  \|____|\  \ \  \___|\ \  \____\ \  \\\  \ \  \\ \  \ \  \\ \  \       \ \  \_\\ \|____|\  \ \  \_\\ \ \  \____  '
echo '    ____\_\  \ \__\    \ \_______\ \_______\ \__\\ \__\ \__\\ \__\       \ \_______\____\_\  \ \_______\ \_______\'
echo '   |\_________\|__|     \|_______|\|_______|\|__| \|__|\|__| \|__|        \|_______|\_________\|_______|\|_______|'
echo '   \|_________|                                                                    \|_________|                   '
echo '__________________________________________________________________________________________________________________'
echo 'Splunk> DSDL Container Build Script for Custom Data-Science Runtimes'

if [ -z "$4" ]; then
  platform="linux/amd64"
  echo "No platform specified. Using default platform: ${platform}"
else
  platform="$4"
fi

if [ -z "$1" ]; then
  echo "No build tag specified. Pick a tag:"
  values=$(cut -d ',' -f 1 tag_mapping.csv)
  echo $values
  exit
else
  tag="$1"
fi

if [ -z "$2" ]; then
  repo="local/"
  echo "No repo name specified. Using default repo name: ${repo}"
else
  repo="$2"
fi

if [ -z "$3" ]; then
  version="latest"
  echo "No version specified. Using version: ${version}"
else
  version="$3"
fi

IFS=',' read -r tag base_image dockerfile base_requirements specific_requirements runtime requirements_dockerfile title <<< "$(grep "^${tag}," tag_mapping.csv)"

if [ -n "$base_image" ]; then
    echo "Tag: $tag"
    echo "Base Image: $base_image"
    echo "Dockerfile: $dockerfile"
    echo "Base Requirements File: $base_requirements"
    echo "Specific Requirements File: $specific_requirements"
    echo "Runtime Options: $runtime"
    echo "Requirements Dockerfile: $requirements_dockerfile"
    echo "Title: $title"
else
    echo "No match found for tag: $tag"
    exit 1
fi

echo "Building custom module."
./build_package.sh

container_name="$repo"mltk-container-$tag
echo "Target container name: $container_name"

echo "Stopping and removing running containers with this name."
docker stop $container_name
docker rm $container_name
docker rmi $container_name

base_requirements_id="${base_requirements%.*}"
specific_requirements_id="${specific_requirements%.*}"

compiled_requirements_id=compiled_${base_requirements_id}_${specific_requirements_id}_$tag
compiled_requirements_filename=./requirements_files/$compiled_requirements_id.txt

echo "Checking for compiled requirements $compiled_requirements_id"

if [[ -f $compiled_requirements_filename ]]; then
  echo "Found pre-compiled requirements: Using $compiled_requirements_id instead of $base_requirements and $specific_requirements"
  base_requirements=$compiled_requirements_id.txt
  specific_requirements="empty".txt
fi


# HDF5 is only available with UBI EPEL subscription, injecting base package installation
# Check if the base image is redhat/ubi9 before running the HDF5 installation script
if [[ "$base_image" == "redhat/ubi9" ]]; then
  echo "Base image is redhat/ubi9, proceeding with HDF5 installation."

  cat << EOF > install_hdf5.sh
#!/bin/bash
set -e

# Install dependencies including C++ tools
dnf install -y wget make gcc gcc-c++ zlib-devel

# Set HDF5 version and installation directory
HDF5_VERSION="1.14.5"
HDF5_DIR="/usr/local/hdf5"

# Download and extract HDF5 from GitHub
wget https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.5/hdf5-1.14.5.tar.gz -O hdf5-${HDF5_VERSION}.tar.gz
tar -xzf hdf5-${HDF5_VERSION}.tar.gz

# Navigate to the extracted directory
cd hdf5-1.14.5

# Configure and build HDF5 without C++, Java, or tests, ensuring library directory is set correctly
./configure --prefix=${HDF5_DIR} --enable-build-mode=production --enable-shared --disable-cxx --disable-tests --disable-java --libdir=${HDF5_DIR}/lib

# Build and install HDF5
make -j$(nproc)
make install

# Remove Java-related components after successful installation to prevent CVE-2020-15250  
rm -rf ${HDF5_DIR}/java/
rm -rf ${HDF5_DIR}/hl/c++/test/

# Verify if libhdf5.so was installed successfully in the correct location
if [ ! -f ${HDF5_DIR}/lib/libhdf5.so ]; then
    echo "Error: HDF5 installation failed. libhdf5.so not found."
    exit 1
fi

# Set environment variables
export HDF5_DIR=${HDF5_DIR}
export LD_LIBRARY_PATH=${HDF5_DIR}/lib:$LD_LIBRARY_PATH
export PATH=${HDF5_DIR}/bin:$PATH

# Add HDF5 library path to system's library path
echo "${HDF5_DIR}/lib" > /etc/ld.so.conf.d/hdf5.conf
ldconfig

# Verify installation
echo "Running HDF5 installation verification..."
echo '#include "hdf5.h"
int main() {
    hid_t file_id = H5Fcreate("test.h5", H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
    H5Fclose(file_id);
    return 0;
}' > test_hdf5.c

gcc -o test_hdf5 test_hdf5.c -I${HDF5_DIR}/include -L${HDF5_DIR}/lib -lhdf5

if ./test_hdf5; then
    echo "HDF5 installation and verification succeeded."
else
    echo "HDF5 verification failed."
    exit 1
fi

# Clean up
rm test_hdf5.c test_hdf5 test.h5
rm -rf hdf5-1.14.5 hdf5-${HDF5_VERSION}.tar.gz

# Create a script to set environment variables
cat << EOT > /etc/profile.d/hdf5.sh
export HDF5_DIR=${HDF5_DIR}
export LD_LIBRARY_PATH=\${HDF5_DIR}/lib:\$LD_LIBRARY_PATH
export PATH=\${HDF5_DIR}/bin:\$PATH
EOT

echo "HDF5 ${HDF5_VERSION} installed successfully in ${HDF5_DIR}"


EOF

  chmod +x install_hdf5.sh
else
  echo "Base image is not redhat/ubi9. Skipping HDF5 installation."
fi


set -x

# Only add the INSTALL_HDF5_SCRIPT build argument if the base image is redhat/ubi9
if [[ "$base_image" == "redhat/ubi9" ]]; then
  docker_build_cmd+=" --build-arg INSTALL_HDF5_SCRIPT=install_hdf5.sh"
fi

# Build the base docker command --no-cache 
docker_build_cmd="docker build --no-cache --rm -t $container_name:$version \
  --build-arg BASE_IMAGE=$base_image \
  --build-arg TAG=$tag \
  --build-arg REQUIREMENTS_PYTHON_BASE=$base_requirements \
  --build-arg REQUIREMENTS_PYTHON_SPECIFIC=$specific_requirements \
  --platform $platform \
  -f ./dockerfiles/$dockerfile"

# Run the docker build 
docker_build_cmd+=" ."
$docker_build_cmd

set +x

# Check exit status
if [ $? -eq 0 ]; then
    echo "Docker build was successful."
else
    echo "Docker build encountered an error."
    exit 1
fi

echo "Creating images.conf, move this file or copy-paste contents into <splunk_dir>/etc/apps/mltk-container/local/images.conf:"

# ensure both options are present if the nvidia runtime is specified
if [ "$runtime" = "nvidia" ]; then
  runtime="none,nvidia"
fi

echo -e "[$tag]\ntitle = $title\nimage = mltk-container-$tag:$version\nrepo = $repo\nruntime = $runtime" > ./images_conf_files/$tag-images.txt

# Remove output file if it already exists
rm -f ./images_conf_files/images.conf

# Loop over all .txt files in the current directory
for file in ./images_conf_files/*-images.txt; do
  # Concatenate the file to the output file
  cat "$file" >> ./images_conf_files/images.conf
done

exit 0