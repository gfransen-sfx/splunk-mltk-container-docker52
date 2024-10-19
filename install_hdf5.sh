#!/bin/bash
set -e

# Install dependencies including C++ tools
dnf install -y wget make gcc gcc-c++ zlib-devel

# Set HDF5 version and installation directory
HDF5_VERSION="1.14.5"
HDF5_DIR="/usr/local/hdf5"

# Download and extract HDF5 from GitHub
wget https://github.com/HDFGroup/hdf5/releases/download/hdf5_1.14.5/hdf5-1.14.5.tar.gz -O hdf5-.tar.gz
tar -xzf hdf5-.tar.gz

# Navigate to the extracted directory
cd hdf5-1.14.5

# Configure and build HDF5 without C++, Java, or tests, ensuring library directory is set correctly
./configure --prefix= --enable-build-mode=production --enable-shared --disable-cxx --disable-tests --disable-java --libdir=/lib

# Build and install HDF5
make -j
make install

# Remove Java-related components after successful installation to prevent CVE-2020-15250  
rm -rf /java/
rm -rf /hl/c++/test/

# Verify if libhdf5.so was installed successfully in the correct location
if [ ! -f /lib/libhdf5.so ]; then
    echo "Error: HDF5 installation failed. libhdf5.so not found."
    exit 1
fi

# Set environment variables
export HDF5_DIR=
export LD_LIBRARY_PATH=/lib:
export PATH=/bin:/Library/Frameworks/Python.framework/Versions/3.12/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin:/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin:/Library/Apple/usr/bin:/Applications/Wireshark.app/Contents/MacOS:/Applications/iTerm.app/Contents/Resources/utilities

# Add HDF5 library path to system's library path
echo "/lib" > /etc/ld.so.conf.d/hdf5.conf
ldconfig

# Verify installation
echo "Running HDF5 installation verification..."
echo '#include "hdf5.h"
int main() {
    hid_t file_id = H5Fcreate("test.h5", H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
    H5Fclose(file_id);
    return 0;
}' > test_hdf5.c

gcc -o test_hdf5 test_hdf5.c -I/include -L/lib -lhdf5

if ./test_hdf5; then
    echo "HDF5 installation and verification succeeded."
else
    echo "HDF5 verification failed."
    exit 1
fi

# Clean up
rm test_hdf5.c test_hdf5 test.h5
rm -rf hdf5-1.14.5 hdf5-.tar.gz

# Create a script to set environment variables
cat << EOT > /etc/profile.d/hdf5.sh
export HDF5_DIR=
export LD_LIBRARY_PATH=${HDF5_DIR}/lib:$LD_LIBRARY_PATH
export PATH=${HDF5_DIR}/bin:$PATH
EOT

echo "HDF5  installed successfully in "


