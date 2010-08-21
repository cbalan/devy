#!/bin/bash -e
#
# Copyright 2010 Catalin Balan. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY CATALIN BALAN ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CATALIN BALAN OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are those of the
# authors and should not be interpreted as representing official policies, either expressed
# or implied, of Catalin Balan.

[ -z "${DRUSH_SOURCE}" ] && DRUSH_SOURCE=http://ftp.drupal.org/files/projects/drush-6.x-3.1.tar.gz
[ -z "${DRUSH_HOME}" ] && DRUSH_HOME=/opt/drush/
[ -z "${DEVY_HOME}" ] && DEVY_HOME=$(readlink -e ./)
[ -z "${DEVY_BUILD_TARGET}" ] && DEVY_BUILD_TARGET=${DEVY_HOME}/target
[ -z "${DEVY_DEVELOP}" ] && DEVY_DEVELOP=0
[ -z "${DEVY_META}" ] && DEVY_META=$DEVY_HOME/devy-meta.sh
[ -z "${DEVY_INSTALL_TARGET}" ] && DEVY_INSTALL_TARGET=/opt/devy
[ -z "${DEVY_INSTALL_WEBDIR}" ] && DEVY_INSTALL_WEBDIR=/var/www/

devy_help="Usage: devy.sh [OPTIONS] -- [WRAPPER OPTIONS]
  --drush [ -- < drush options > ] : Drush wrapper. If drush is not installed
                                   : it will be downloaded from ${DRUSH_SOURCE}
  --drush-install                  : Install drush under ${DRUSH_HOME} and link it under /usr/bin/drush
  --drush-uninstall                : The oposite of --drush-install
  --build                          : Runs drush make for devy.make. Deployes overlays.
                                   : Should be executed under the root of the project. ie. devy/.
                                   : All build arguments can be overided in ${DEVY_META}
                                   : For more details see Devy Meta section.
                                   : Build result can be found under ${DEVY_BUILD_TARGET} folder.
  --package                        : 'tar czf' build result.
  --install                        : Copy ${DEVY_BUILD_TARGET} to ${DEVY_INSTALL_TARGET}
  --install-www                    : Creates links between ${DEVY_INSTALL_TARGET} and ${DEVY_INSTALL_WEBDIR}
                                   : based on DEVY_INSTALL_WWW_* definitions.
                                   : If --develop flag is present devy.sh will create symlinks between
                                   : ${DEVY_BUILD_TARGET} and ${DEVY_INSTALL_WEBDIR} folder.
  --develop                        : For local overlay folders, symbolic links will be used in place of rsync.
  --debug                          : Enables bash's xtrace feature.
  --install-develop                : Alias for : --clean --develop --install-www
  --help                           : Executes 'format c:\' :)
  
Devy meta file format:
 DEVY_BUILD_OVERLAY_MAGENTO='package.tgz local_folder'         : Magento overlay definition
 DEVY_BUILD_OVERLAY_{ target directory }='{List of archives/patches/folders}' : Any other overlay can be specified in this format.

 PACKAGE_VERSION=1.2-$(date +%Y%m%d%H%M)                       : A cool svn status call can be used here also.
 PACKAGE_PREFIX=devy                                           : Usually the project's name

 # WWW destinations
 DEVY_INSTALL_WWW_DRUPAL='${DEVY_INSTALL_WEBDIR}/my-drupal'      : devy.sh will deploy drupal
                                                                 : installation to '${DEVY_INSTALL_WEBDIR}/my-drupal' folder
 DEVY_INSTALL_WWW_MAGENTO='${DEVY_INSTALL_WEBDIR}/magento'
 
 DEVY_INSTALL_WWW_{ component name }={ instalation folder }

 # Hooks. Function name that should be called at a particular event.
 HOOK_DEVY_BUILD_PRE='function_name'
 HOOK_DEVY_BUILD_POST='function_name'
 HOOK_DEVY_BUILD_OVERLAYS_ITEM='function_name' : Overides devy_overlay method
                                               : Called for each defined overlay item
                                               : Arguments: $1-overlay, $2-overlay-target

Limitations:
  * Overlays:
    - For remote files, only http and svn 'protocols' are supported.
    - For files, only tgz archives are supported
    - No target subdirectories are supported. ie. DEVY_BUILD_OVERLAY_FOO_BAR will generates a /target/foo_bar/ destination
  * Drush Make: Only one drush make file is supported. Use drush make includes if more files are required.

Sample Devy Meta file:
 # Overlays. Devy build script will rsync all items one on top of the next one, in that order to target/magento
 DEVY_BUILD_OVERLAY_MAGENTO='http://url-to-magento-enterprise/package.tgz custom_patch1.patch custom_patch2.patch \${DEVY_HOME}/local_magento/'

 # This will do the same, but the result will be found under target/othercomponent. Multiline should work also. 
 DEVY_BUILD_OVERLAY_OTHERCOMPONENT='http://url-to-cool-component/package.tgz
 /path/to/custom/patches/custom_patch.patch
 /path/to/custom/patches/custom_patch1.patch
 /path/to/custom/patches/custom_patch2.patch
 \${DEVY_HOME}/my-customization-for-cool-component/'
 
 # Other projects can extend devy core project like this:
 DEVY_BUILD_OVERLAY_DRUPAL='http://some-s3-bucket.s3.amazonws.com/devy-drupal-1.2.3.tgz
 ${DEVY_HOME}/my_local_drupal_customizations'

 DEVY_BUILD_OVERLAY_MAGENTO='http://some-s3-bucket.s3.amazonws.com/devy-magento-1.2.3.tgz
 ${DEVY_HOME}/my_local_magento_customizations/'

 DEVY_BUILD_OVERLAY_MAP='http://some-s3-bucket.s3.amazonws.com/devy-map-1.2.3.tgz
 ${DEVY_HOME}/my_local_map_customizations/'
"

function devy_drush_get() {
  temp_dir=$(mktemp -d)
  curl ${DRUSH_SOURCE} | tar -xz -C ${temp_dir}
  echo $(find $temp_dir -maxdepth 1 -type d|tail -n1)
}

function devy_drush_install() {
  if [ -z "$(which drush)" ];then  
    drush_tmp=$(devy_drush_get)
    if [ ! -d ${DRUSH_HOME} ];then
      echo "[drush-install] Installing drush under ${DRUSH_HOME}"
      sudo cp -a ${drush_tmp} ${DRUSH_HOME}
      rm -rf ${drush_tmp}
      echo "[drush-install] Setting up drush symlink from ${DRUSH_HOME}/drush to /usr/bin/drush"
      sudo ln -sf ${DRUSH_HOME}/drush /usr/bin/
    else
      echo "[drush-install] Unable to install drush to ${DRUSH_HOME}. Target directory exists."
      exit 1
    fi
  fi
}

function devy_drush_uninstall() {
  echo "[drush-uninstall] Removing drush files: ${DRUSH_HOME} /usr/bin/drush"
  sudo rm -rf $DRUSH_HOME /usr/bin/drush
}

function devy_drush() {
  drush=$(which drush)
  
  # no drush found. Just download it.
  if [ -z "$drush" ]; then  
    drush_tmp=$(devy_drush_get)
    drush=${drush_tmp}/drush
  fi

  echo "[drush] Executing drush from ${drush} with '$*' arguments."
  $drush $*
  drush_exit=$?
  
  # clean up drush tmp 
  [ -n "$drush_tmp" ] && rm -rf $drush_tmp
  
  # exit with drush exit code
  if [ $drush_exit != 0 ]; then 
    exit $drush_exit
  fi
}

function devy_overlay() {
  src=$1; target=$2; src_remote=0
  echo "[overlay] Applying ${src} overlay to ${target}"
  
  if [ ${src:${#src}-6} == ".patch" ]; then
    patch -d $target -p${DEVY_OVERLAY_PATCH_PNUM:-0} < $src
    return
  fi
  
  if [ ${src:0:11} == "drush_make:" ]; then
    devy_drush dl drush_make
    devy_drush make ${src##drush_make:} ${target}
    return
  fi
  
  if [ ${src:0:4} == 'http' -o ${src:0:4} == 'svn:' -o -f $src ]; then
    temp_dir=$(mktemp -d); temp_file=$(mktemp -u)
    
    if [ ${src:0:4} == 'http' ]; then
      wget $src -O ${temp_file}
    elif [ ${src:0:4} == 'svn:' ]; then
      svn export ${src##svn:} ${temp_file}
    elif [ -f $src ]; then
      temp_file=$src
    fi
    
    if [ -f $temp_file ]; then
      tar -xf $temp_file -C $temp_dir
      src=$(find $temp_dir -maxdepth 1 -type d | tail -n1)
    elif [ -d $temp_file ]; then 
      src=$temp_file
    elif [ ! -e $temp_file ]; then
      echo "[overlay] Unable to apply ${src} to ${target}. ${src} not found."
      return
    fi
    
    src_remote=1
  fi
  
  if [ $src_remote == 0 -a -d $src -a $DEVY_DEVELOP == 1 ]; then
    echo "[overlay] Finding development files."
    
    devfiles=$(find $src \! -path "*.svn*")
    devfiles_count=$(echo "$devfiles"|wc -l)
    echo "[overlay] ${devfiles_count} files found."
    echo "[overlay] Creating symlinks for development files."
    
    i=0
    (
      IFS=$'\n'
      for devfile in $devfiles; do
        destfile=$target/${devfile#$src}
        if [ ! -e $destfile -o -f $destfile -a ! $destfile -ef $devfile  ]; then
          ln -sf $devfile ${destfile%/}
        fi
        
        i=$(($i+1)); echo -ne " $i/${devfiles_count} \r"
      done
    )
  else
    rsync -a --exclude .svn ${src%/}/ ${target%/}/
  fi
}
 
function devy_build () {
  if [ -f $DEVY_META ]; then
    source $DEVY_META
  fi

  if [ -n "${HOOK_DEVY_BUILD_PRE}" ]; then
    echo "[build] Executing HOOK_DEVY_BUILD_PRE:${HOOK_DEVY_BUILD_PRE} hook."
    ${HOOK_DEVY_BUILD_PRE}
  fi

  for overlays in ${!DEVY_BUILD_OVERLAY_*}; do
    overlays_target=${overlays##DEVY_BUILD_OVERLAY_}
    overlays_target=${DEVY_BUILD_TARGET}/${overlays_target,,}
    
    echo -e "[build-overlays] Building ${overlays_target} from the following overlays:\n${!overlays}"
    for overlay in ${!overlays}; do
      if [ -z "${HOOK_DEVY_BUILD_OVERLAYS_ITEM}" ]; then
        devy_overlay "${overlay}" "${overlays_target}"
      else
        echo "[build-overlays] Executing HOOK_DEVY_BUILD_OVERLAYS_ITEM:${HOOK_DEVY_BUILD_OVERLAYS_ITEM} '${overlay} ${overlays_target}' hook."
        ${HOOK_DEVY_BUILD_OVERLAYS_ITEM} "${overlay}" "${overlays_target}"
      fi
    done
  done

  if [ -n "${HOOK_DEVY_BUILD_POST}" ]; then
    echo "[build] executing HOOK_DEVY_BUILD_POST:${HOOK_DEVY_BUILD_POST} hook."
    ${HOOK_DEVY_BUILD_POST}
  fi
}
  
function devy_package () {
  if [ -f $DEVY_META ]; then
    source $DEVY_META
  fi
  
  [ -z "${PACKAGE_VERSION}" ] && PACKAGE_VERSION="1.0"
  [ -z "${PACKAGE_PREFIX}" ] && PACKAGE_PREFIX="devy"
  
  if [ ! -d ${DEVY_BUILD_TARGET} ]; then
    devy_build
  fi
  echo "[package] Packing ${PACKAGE_PREFIX}-${PACKAGE_VERSION} project."
  for package_src in $(find ${DEVY_BUILD_TARGET} -maxdepth 1 -type d -printf "%f\n"|tail -n+2); do
    package_file=${DEVY_BUILD_TARGET}/${PACKAGE_PREFIX}-${package_src}-${PACKAGE_VERSION}.tgz
    echo "[package] Packing ${package_src} to ${package_file}"
    tar -C ${DEVY_BUILD_TARGET} -czf ${package_file} ${package_src}
  done
}

function devy_install () {
  if [ ! -d ${DEVY_BUILD_TARGET} ]; then
    devy_build
  fi

  if [ -f $DEVY_META ]; then
    source $DEVY_META
  fi

  if [ -n "${HOOK_DEVY_INSTALL_PRE}" ]; then
    echo "[install] Executing HOOK_DEVY_INSTALL_PRE:${HOOK_DEVY_INSTALL_PRE} hook."
    ${HOOK_DEVY_INSTALL_PRE}
  fi

  mkdir -p ${DEVY_INSTALL_TARGET}
  for package_name in $(find ${DEVY_BUILD_TARGET} -maxdepth 1 -type d -printf "%f\n"|tail -n+2); do
    rm -rf ${DEVY_INSTALL_TARGET}/${package_name}
    cp -a ${DEVY_BUILD_TARGET}/${package_name} ${DEVY_INSTALL_TARGET}/${package_name}
  done
  
  if [ -n "${HOOK_DEVY_INSTALL_POST}" ]; then
    echo "[install] Executing HOOK_DEVY_INSTALL_POST:${HOOK_DEVY_INSTALL_POST} hook."
    ${HOOK_DEVY_INSTALL_POST}
  fi
}

function devy_install_www() {
  if [ $DEVY_DEVELOP == 0 ]; then 
    if [ ! -d ${DEVY_INSTALL_TARGET} ]; then
      devy_install
    fi
  else
    if [ ! -d ${DEVY_BUILD_TARGET} ]; then
      devy_build
    fi
  fi
  
  if [ -f $DEVY_META ]; then
    source $DEVY_META
  fi

  if [ -n "${HOOK_DEVY_INSTALL_WWW_PRE}" ]; then
    echo "[install] Executing HOOK_DEVY_INSTALL_WWW_PRE:${HOOK_DEVY_INSTALL_WWW_PRE} hook."
    ${HOOK_DEVY_INSTALL_WWW_PRE}
  fi

  for www_dest in ${!DEVY_INSTALL_WWW_*}; do
    package_name=${www_dest##DEVY_INSTALL_WWW_}
    package_name=${package_name,,}
    package_www=${!www_dest}
    
    if [ $DEVY_DEVELOP == 0 ]; then
      temp_dir="$(mktemp -d -p ${DEVY_INSTALL_WEBDIR} tmp.${package_name%/}.XXXXXX)"
      
      # Install component under temp www dir
      rsync -a --exclude .svn ${DEVY_INSTALL_TARGET}/${package_name%/}/ ${temp_dir%/}/
      
      persist_key="PERSIST_DEVY_INSTALL_WWW_${package_name^^}"
      if [ -d ${package_www} -a -n "${!persist_key}" ]; then 
        for persist_file in ${!persist_key}; do
          mkdir -p $(dirname ${temp_dir}/${persist_file})
          cp -a ${package_www}/${persist_file} ${temp_dir}/${persist_file}
        done
      fi
      
      rm -rf ${package_www}
      mv ${temp_dir} ${package_www}
      chmod -R 755 ${package_www}
    else
      sudo rm -rf ${package_www}
      sudo ln -s ${DEVY_BUILD_TARGET}/${package_name%/} ${package_www%/}
    fi
  done
  
  if [ -n "${HOOK_DEVY_INSTALL_WWW_POST}" ]; then
    echo "[install] Executing HOOK_DEVY_INSTALL_WWW_POST:${HOOK_DEVY_INSTALL_WWW_POST} hook."
    ${HOOK_DEVY_INSTALL_WWW_POST}
  fi
}

function devy_clean() {
  echo "[clean] Cleaning ${DEVY_BUILD_TARGET} folder."
  rm -rf ${DEVY_BUILD_TARGET}
}

# Argument handling 
if [ ${0##*/} == "devy.sh" ]; then
  if [ $# == 0 ]; then
    echo "$devy_help"
    exit 0
  fi

  options="-l drush
  -l drush-install
  -l drush-uninstall
  -l build
  -l clean
  -l package
  -l install
  -l install-www
  -l install-develop
  -l overlay:
  -l overlay-target:
  -l develop
  -l debug
  -l help"
  
  args=$(getopt ${options} "" "$@")
  if [ ! "$?" == "0" ]; then
    exit 1
  fi
  actions=""
  for arg in $args; do
    case $arg in
      --help            ) echo "$devy_help";exit;;
      --drush           ) actions="${actions} drush";shift;;
      --drush-install   ) actions="${actions} devy_drush_install";shift;;
      --drush-uninstall ) actions="${actions} devy_drush_uninstall";shift;;
      --build           ) actions="${actions} devy_build";shift;;
      --clean           ) actions="${actions} devy_clean";shift;;
      --package         ) actions="${actions} devy_package";shift;;
      --install         ) actions="${actions} devy_install";shift;;
      --install-www     ) actions="${actions} devy_install_www";shift;;
      --overlay         ) actions="${actions} devy_overlay";overlay_src="${overlay_src} $2";shift;shift;;
      --overlay-target  ) overlay_target=$2;shift;shift;;
      --develop         ) DEVY_DEVELOP=1;shift;;
      --debug           ) set -x;shift;;
      --install-develop ) DEVY_DEVELOP=1;actions="devy_clean devy_install_www";shift;;
      --                ) [ $# -gt 0 ] && shift;args_nooption=$@;break;;
    esac
  done

  for action in $actions; do
    if [ -n "$action" ]; then
      case $action in
        "drush"                     ) devy_drush $args_nooption; exit 0;;
        "devy_drush_install"    ) devy_drush_install;;
        "devy_drush_uninstall"  ) devy_drush_uninstall;;
        "devy_overlay"          ) if [ -z "${devy_overlay_action_executed}" ]; then
                                        for overlay in $overlay_src; do
                                          devy_overlay "$overlay" "${overlay_target:-./}"
                                        done
                                        devy_overlay_action_executed=1  
                                      fi;;
        "devy_build"            ) devy_build;;
        "devy_clean"            ) devy_clean;;
        "devy_package"          ) devy_package;;
        "devy_install"          ) devy_install;;
        "devy_install_www"      ) devy_install_www;;
      esac
    fi
  done
fi
