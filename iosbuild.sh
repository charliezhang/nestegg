#!/bin/sh

# Cross-compile nestegg library for different architectures.

# List of supported architectures.
ARCHS="x86_64 arm64"

FRAMEWORK_DIR="nestegg.framework"
HEADER_DIR="$FRAMEWORK_DIR/Headers"
OUTDIR="./outdir"
IOS_DEPLOY_TGT="7.1"

setenv_all()
{
        export LD=`xcrun -find -sdk iphoneos ld`
        export AR=`xcrun -find -sdk iphoneos ar`
        export AS=`xcrun -find -sdk iphoneos as`
        export nm=`xcrun -find -sdk iphoneos nm`
        export ranlib=`xcrun -find -sdk iphoneos ranlib`
       
        export CPPFLAGS=$CFLAGS
        export CXXFLAGS=$CFLAGS
}

export configure_flags_arm64=" --host=arm-apple-darwin6 --enable-shared=no"

setenv_arm64()
{
        export SDKROOT="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS$IOS_DEPLOY_TGT.sdk"
        export LDFLAGS="-L$SDKROOT/usr/lib/"
        export CFLAGS="-arch arm64 -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$IOS_DEPLOY_TGT -I$SDKROOT/usr/include/"
        
        export CC=`xcrun -find -sdk iphoneos cc`
        export CXX=`xcrun -find -sdk iphoneos c++`
        
        setenv_all
}

export configure_flags_x86_64=" --enable-shared=no"

setenv_x86_64()
{
        setenv_all
}

cleanup() {
  rm -rf $OUTDIR
}

trap cleanup EXIT  

build_framework() {
  local archs=$1
  
  eval rm -rf \$OUTDIR $DEVNULL
  liblist=""
  for arch in $archs; do
   
    echo "*** Start building for architecture: $arch ***"

    mkdir -p $OUTDIR/$arch
    eval make clean $DEVNULL
    eval make distclean $DEVNULL
    unset CFLAGS CC LD CPP CXX AR AS NM RANLIB LDFLAGS CPPFLAGS CXXFLAGS
    eval setenv_$arch
    cfg_flags=configure_flags_$arch
    cfg_flags=${!cfg_flags}
    CFLAGS=$CFLAGS && eval ./configure \$cfg_flags $DEVNULL
    
    eval make -j4 $DEVNULL
    cp -rvf src/.libs/lib*.a $OUTDIR/$arch
    lib_list="$lib_list $OUTDIR/$arch/libnestegg.a"
    
    echo "*** Done building for architecture: $arch ***"

  done

  eval rm -rf \$FRAMEWORK_DIR $DEVNULL
  mkdir -p $HEADER_DIR
  cp include/nestegg/*.h $HEADER_DIR

  echo "Creating FAT library"
  lipo -create $lib_list -output $FRAMEWORK_DIR/nestegg

  lipo -info $FRAMEWORK_DIR/nestegg
}

TARGETS="x86_64-apple-darwin13.3.0"

build_target() {
  local target="$1"
  vlog "***Building target: ${target}***"
  # mkdir  "${target}"
  # cd "${target}"
  eval "./configure" --host="${target}"
  export DIST_DIR
  eval make -j 1
  # cd ..
  vlog "***Done building target: ${target}***"
}

vlog() {
  if [ "${VERBOSE}" = "yes" ]; then
    echo "$@"
  fi
}

# Parse the command line.
while [ -n "$1" ]; do
  case "$1" in
    --help)
      echo "sh iosbuild.sh --verbose"
      exit
      ;;
    --verbose)
      VERBOSE=yes
      ;;
    *)
      iosbuild_usage
      exit 1
      ;;
  esac
  shift
done

DEVNULL=
if [ "${VERBOSE}" != "yes" ]; then
  DEVNULL=' > /dev/null 2>& 1'
fi

build_framework "$ARCHS"
