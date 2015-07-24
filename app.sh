CFLAGS="${CFLAGS:-} -ffunction-sections -fdata-sections"
LDFLAGS="${LDFLAGS:-} -L${DEPS}/lib -Wl,--gc-sections"

### MYSQL-CONNECTOR ###
_build_mysqlc() {
local VERSION="6.1.6"
local FOLDER="mysql-connector-c-${VERSION}-src"
local FILE="${FOLDER}.tar.gz"
local URL="http://cdn.mysql.com/Downloads/Connector-C/${FILE}"
export FOLDER_NATIVE="${PWD}/target/${FOLDER}-native"
export QEMU_LD_PREFIX="${TOOLCHAIN}/${HOST}/libc"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"

if [ ! -f "${FOLDER_NATIVE}/extra/comp_err" ]; then
  cp -faR "target/${FOLDER}" "${FOLDER_NATIVE}"
  # native compilation of comp_err
  ( . uncrosscompile.sh
    pushd "${FOLDER_NATIVE}"
    cmake .
    make comp_err )
fi

pushd "target/${FOLDER}"
cat > "cmake_toolchain_file.${ARCH}" << EOF
SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_SYSTEM_PROCESSOR ${ARCH})
SET(CMAKE_C_COMPILER ${CC})
SET(CMAKE_CXX_COMPILER ${CXX})
SET(CMAKE_AR ${AR})
SET(CMAKE_RANLIB ${RANLIB})
SET(CMAKE_STRIP ${STRIP})
SET(CMAKE_CROSSCOMPILING TRUE)
SET(STACK_DIRECTION 1)
SET(CMAKE_FIND_ROOT_PATH ${TOOLCHAIN}/${HOST}/libc)
SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

cmake . -DCMAKE_TOOLCHAIN_FILE="./cmake_toolchain_file.${ARCH}" -DCMAKE_AR="${AR}" -DCMAKE_STRIP="${STRIP}" -DCMAKE_INSTALL_PREFIX="${DEPS}" -DENABLED_PROFILING=OFF -DENABLE_DEBUG_SYNC=OFF -DWITH_PIC=ON -DHAVE_LLVM_LIBCPP_EXITCODE=1 -DHAVE_GCC_ATOMIC_BUILTINS=1

if ! make -j1; then
  sed -e "s|\&\& comp_err|\&\& ./comp_err|g" -i extra/CMakeFiles/GenError.dir/build.make
  cp -vf "${FOLDER_NATIVE}/extra/comp_err" extra/
  make -j1
fi
make install
rm -vf "${DEPS}/lib"/libmysql*.so*
cp -vfaR include/*.h "${DEPS}/include/"
popd
}

### MYSQL-PYTHON ###
_build_mysql_python() {
local VERSION="1.2.4b4"
local FOLDER="MySQL-python-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://sourceforge.net/projects/mysql-python/files/mysql-python-test/${VERSION}/${FILE}"
local XPYTHON="${HOME}/xtools/python2/${DROBO}"
export SSL_CERT_FILE="${XPYTHON}/etc/ssl/certs/ca-certificates.crt"
local BASE="${PWD}"
export QEMU_LD_PREFIX="${TOOLCHAIN}/${HOST}/libc"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
echo "mysql_config = ${DEPS}/bin/mysql_config" >> site.cfg
PKG_CONFIG_PATH="${XPYTHON}/lib/pkgconfig" \
  LDFLAGS="${LDFLAGS:-} -Wl,-rpath,/mnt/DroboFS/Share/DroboApps/python2/lib -L${XPYTHON}/lib" \
  "${XPYTHON}/bin/python" setup.py build_ext \
  --include-dirs="${XPYTHON}/include" --library-dirs="${XPYTHON}/lib" \
  --force build --force bdist_egg --dist-dir "${BASE}"
popd
}

### BUILD ###
_build() {
  _build_mysqlc
  _build_mysql_python
}

_clean() {
  rm -v -fr *.egg
  rm -vfr "${DEPS}"
  rm -vfr "${DEST}"
  rm -v -fr target/*
}
