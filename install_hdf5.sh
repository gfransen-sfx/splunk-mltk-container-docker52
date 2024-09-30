#!/bin/bash
set -e

# Install dependencies including C++ tools
dnf install -y wget make gcc gcc-c++ zlib-devel

# Set HDF5 version and installation directory
HDF5_VERSION="1.14.4-3"
HDF5_DIR="/usr/local/hdf5"

# Download and extract HDF5 from GitHub
wget https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.4.3/hdf5-1.14.4-3.tar.gz -O hdf5-${HDF5_VERSION}.tar.gz
tar -xzf hdf5-${HDF5_VERSION}.tar.gz

# Navigate to the extracted directory
cd hdf5-1.14.4-3

# Configure and build HDF5 without C++ API (to avoid _Float16 error)
./configure --prefix=${HDF5_DIR} --enable-build-mode=production --enable-shared --disable-cxx
make -j$(nproc)
make install

# Set environment variables
export HDF5_DIR=${HDF5_DIR}
export LD_LIBRARY_PATH=${HDF5_DIR}/lib:$LD_LIBRARY_PATH
export PATH=${HDF5_DIR}/bin:$PATH

# Add HDF5 library path to system's library path
echo "${HDF5_DIR}/lib" > /etc/ld.so.conf.d/hdf5.conf
ldconfig

# Verify installation
if [ ! -f ${HDF5_DIR}/lib/libhdf5.so ]; then
    echo "Error: HDF5 installation failed. libhdf5.so not found."
    exit 1
fi

# Run a simple test to verify installation
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
rm -rf hdf5-1.14.4-3 hdf5-${HDF5_VERSION}.tar.gz

# Create a script to set environment variables
cat << EOT > /etc/profile.d/hdf5.sh
export HDF5_DIR=
export LD_LIBRARY_PATH=${HDF5_DIR}/lib:$LD_LIBRARY_PATH
export PATH=${HDF5_DIR}/bin:$PATH
EOT

echo "HDF5 ${HDF5_VERSION} installed successfully in ${HDF5_DIR}"

