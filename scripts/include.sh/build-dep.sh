#!/bin/sh

build_git_ios()
{
  if test "x$name" = x ; then
    return
  fi

  simarchs="i386 x86_64"
  if xcodebuild -showsdks 2>/dev/null|grep iphoneos8.1 >/dev/null ; then
    sdkversion=8.1
    devicearchs="armv7 armv7s arm64"
  elif xcodebuild -showsdks 2>/dev/null|grep iphoneos8.0 >/dev/null ; then
    sdkversion=8.0
    devicearchs="armv7 armv7s arm64"
  elif xcodebuild -showsdks 2>/dev/null|grep iphoneos7.1 >/dev/null ; then
    sdkversion=7.1
    devicearchs="armv7 armv7s arm64"
  elif xcodebuild -showsdks 2>/dev/null|grep iphoneos7.0 >/dev/null ; then
    sdkversion=7.0
    devicearchs="armv7 armv7s arm64"
  elif xcodebuild -showsdks 2>/dev/null|grep iphoneos6.1 >/dev/null ; then
    sdkversion=6.1
    devicearchs="armv7 armv7s"
  else
    echo SDK not found
    exit 1
  fi

  versions_path="$scriptpath/deps-versions.plist"
  version="`defaults read "$versions_path" "$name" 2>/dev/null`"
  version="$(($version+1))"
  if test x$build_for_external = x1 ; then
    version=0
  fi

  if test x$build_for_external = x1 ; then
    builddir="$scriptpath/../Externals/tmp/dependencies"
  else
    builddir="$HOME/MailCore-Builds/dependencies"
  fi
  BUILD_TIMESTAMP=`date +'%Y%m%d%H%M%S'`
  tempbuilddir="$builddir/workdir/$BUILD_TIMESTAMP"
  mkdir -p "$tempbuilddir"
  srcdir="$tempbuilddir/src"
  logdir="$tempbuilddir/log"
  resultdir="$builddir/builds"
  tmpdir="$tempbuilddir/tmp"

  echo "working in $tempbuilddir"

  mkdir -p "$resultdir"
  mkdir -p "$logdir"
  mkdir -p "$tmpdir"
  mkdir -p "$srcdir"

  pushd . >/dev/null
  mkdir -p "$builddir/downloads"
  cd "$builddir/downloads"
  if test -d "$name" ; then
    cd "$name"
    git checkout master
    git pull --rebase
  else
    git clone $url "$name"
    cd "$name"
  fi
  #version=`echo $rev | cut -c1-10`

  popd >/dev/null

  pushd . >/dev/null

  cp -R "$builddir/downloads/$name" "$srcdir/$name"
  cd "$srcdir/$name"
  if test "x$branch" != x ; then
    if ! git checkout -b "$branch" "origin/$branch" ; then
      git checkout "$branch"
    fi
  fi
  git checkout -q $rev
  echo building $name $version - $rev

  cd "$srcdir/$name/build-mac"
  sdk="iphoneos$sdkversion"
  echo building $sdk
  xctool -project "$xcode_project" -sdk $sdk -scheme "$xcode_target" -configuration Release SYMROOT="$tmpdir/bin" OBJROOT="$tmpdir/obj" ARCHS="$devicearchs" IPHONEOS_DEPLOYMENT_TARGET="$sdkversion"
  if test x$? != x0 ; then
    echo failed
    exit 1
  fi
  sdk="iphonesimulator$sdkversion"
  echo building $sdk
  xctool -project "$xcode_project" -sdk $sdk -scheme "$xcode_target" -configuration Release SYMROOT="$tmpdir/bin" OBJROOT="$tmpdir/obj" ARCHS="$simarchs" IPHONEOS_DEPLOYMENT_TARGET="$sdkversion"
  if test x$? != x0 ; then
    echo failed
    exit 1
  fi
  echo finished

  if echo $library|grep '\.framework$'>/dev/null ; then
    cd "$tmpdir/bin/Release"
    defaults write "$tmpdir/bin/Release/$library/Resources/Info.plist" "git-rev" "$rev"
    mkdir -p "$resultdir/$name"
    zip -qry "$resultdir/$name/$name-$version.zip" "$library"
  else
    cd "$tmpdir/bin"
    mkdir -p "$name-$version/$name"
    mkdir -p "$name-$version/$name/lib"
    mv Release-iphoneos/include "$name-$version/$name"
    lipo -create "Release-iphoneos/$library" \
      "Release-iphonesimulator/$library" \
        -output "$name-$version/$name/lib/$library"
    for dep in $embedded_deps ; do
      if test -d "$srcdir/$name/build-mac/$dep" ; then
        mv "$srcdir/$name/build-mac/$dep" "$name-$version"
      elif test -d "$srcdir/$name/Externals/$dep" ; then
        mv "$srcdir/$name/Externals/$dep" "$name-$version"
      else
        echo Dependency $dep not found
      fi
      if test x$flatten_deps=x1 ; then
        cp -R "$name-$version/$dep"/* "$name-$version/$name"
        rm -rf "$name-$version/$dep"
      fi
    done
    if test x$flatten_deps=x1 ; then
      mv "$name-$version/$name"/* "$name-$version"
      rm -rf "$name-$version/$name"
    fi
    echo "$rev"> "$name-$version/git-rev"
    if test x$build_for_external = x1 ; then
      mkdir -p "$scriptpath/../Externals"
      cp -R "$name-$version"/* "$scriptpath/../Externals"
      rm -f "$scriptpath/../Externals/git-rev"
    else
      mkdir -p "$resultdir/$name"
      zip -qry "$resultdir/$name/$name-$version.zip" "$name-$version"
    fi
  fi

  echo build of $name-$version done

  popd >/dev/null

  echo cleaning
  rm -rf "$tempbuilddir"

  if test x$build_for_external != x1 ; then
    defaults write "$versions_path" "$name" "$version"
  fi
}

build_git_osx()
{
  sdk="macosx10.9"
  archs="x86_64"
  
  if test "x$name" = x ; then
    return
  fi
  
  versions_path="$scriptpath/deps-versions.plist"
  version="`defaults read "$versions_path" "$name" 2>/dev/null`"
  version="$(($version+1))"
  if test x$build_for_external = x1 ; then
    version=0
  fi

  if test x$build_for_external = x1 ; then
    builddir="$scriptpath/../Externals/tmp/dependencies"
  else
    builddir="$HOME/MailCore-Builds/dependencies"
  fi
  BUILD_TIMESTAMP=`date +'%Y%m%d%H%M%S'`
  tempbuilddir="$builddir/workdir/$BUILD_TIMESTAMP"
  mkdir -p "$tempbuilddir"
  srcdir="$tempbuilddir/src"
  logdir="$tempbuilddir/log"
  resultdir="$builddir/builds"
  tmpdir="$tempbuilddir/tmp"

  echo "working in $tempbuilddir"

  mkdir -p "$resultdir"
  mkdir -p "$logdir"
  mkdir -p "$tmpdir"
  mkdir -p "$srcdir"

  pushd . >/dev/null
  mkdir -p "$builddir/downloads"
  cd "$builddir/downloads"
  if test -d "$name" ; then
  	cd "$name"
    git checkout master
  	git pull --rebase
  else
  	git clone $url "$name"
  	cd "$name"
  fi
  #version=`echo $rev | cut -c1-10`

  popd >/dev/null

  pushd . >/dev/null

  cp -R "$builddir/downloads/$name" "$srcdir/$name"
  cd "$srcdir/$name"
  if test "x$branch" != x ; then
    if ! git checkout -b "$branch" "origin/$branch" ; then
      git checkout "$branch"
    fi
  fi
  git checkout -q $rev
  echo building $name $version - $rev

  cd "$srcdir/$name/build-mac"
  xctool -project "$xcode_project" -sdk $sdk -scheme "$xcode_target" -configuration Release ARCHS="$archs" SYMROOT="$tmpdir/bin" OBJROOT="$tmpdir/obj"
  if test x$? != x0 ; then
    echo failed
    exit 1
  fi
  echo finished
  
  if echo $library|grep '\.framework$'>/dev/null ; then
    cd "$tmpdir/bin/Release"
    defaults write "$tmpdir/bin/Release/$library/Resources/Info.plist" "git-rev" "$rev"
    mkdir -p "$resultdir/$name"
    zip -qry "$resultdir/$name/$name-$version.zip" "$library"
  else
    cd "$tmpdir/bin"
    mkdir -p "$name-$version/$name"
    mkdir -p "$name-$version/$name/lib"
    mv Release/include "$name-$version/$name"
    mv "Release/$library" "$name-$version/$name/lib"
    for dep in $embedded_deps ; do
      if test -d "$srcdir/$name/build-mac/$dep" ; then
        mv "$srcdir/$name/build-mac/$dep" "$name-$version"
      elif test -d "$srcdir/$name/Externals/$dep" ; then
        mv "$srcdir/$name/Externals/$dep" "$name-$version"
      else
        echo Dependency $dep not found
      fi
      if test x$flatten_deps=x1 ; then
        cp -R "$name-$version/$dep"/* "$name-$version/$name"
        rm -rf "$name-$version/$dep"
      fi
    done
    if test x$flatten_deps=x1 ; then
      mv "$name-$version/$name"/* "$name-$version"
      rm -rf "$name-$version/$name"
    fi
    echo "$rev"> "$name-$version/git-rev"
    if test x$build_for_external = x1 ; then
      mkdir -p "$scriptpath/../Externals"
      cp -R "$name-$version"/* "$scriptpath/../Externals"
      rm -f "$scriptpath/../Externals/git-rev"
    else
      mkdir -p "$resultdir/$name"
      zip -qry "$resultdir/$name/$name-$version.zip" "$name-$version"
    fi
  fi

  echo build of $name-$version done

  popd >/dev/null

  echo cleaning
  rm -rf "$tempbuilddir"

  if test x$build_for_external != x1 ; then
    defaults write "$versions_path" "$name" "$version"
  fi
}

get_prebuilt_dep()
{
  url="http://d.etpan.org/mailcore2-deps"

  if test "x$name" = x ; then
    return
  fi
  
  versions_path="$scriptpath/deps-versions.plist"
  installed_versions_path="$scriptpath/installed-deps-versions.plist"
  if test ! -f "$versions_path" ; then
    build_for_external=1 "$scriptpath/build-$name.sh"
    return;
  fi
  
  installed_version="`defaults read "$installed_versions_path" "$name" 2>/dev/null`"
  if test ! -d "$scriptpath/../Externals/$name" ; then
    installed_version=
  fi
  if test "x$installed_version" = x ; then
    installed_version="none"
  fi
  version="`defaults read "$versions_path" "$name" 2>/dev/null`"

  echo $name, installed: $installed_version, required: $version
  if test "x$installed_version" = "x$version" ; then
    return
  fi

  BUILD_TIMESTAMP=`date +'%Y%m%d%H%M%S'`
  tempbuilddir="$scriptpath/../Externals/workdir/$BUILD_TIMESTAMP"
  
  mkdir -p "$tempbuilddir"
  cd "$tempbuilddir"
  echo "Downloading $name-$version"
  curl -O "$url/$name/$name-$version.zip"
  unzip -q "$name-$version.zip"
  rm -rf "$scriptpath/../Externals/$name"
  mv "$name-$version"/* "$scriptpath/../Externals"
  rm -f "$scriptpath/../Externals/git-rev"
  rm -rf "$tempbuilddir"
  
  if test -d "$scriptpath/../Externals/$name" ; then
    defaults write "$installed_versions_path" "$name" "$version"
  fi
}
