# The purpose of this file is to describe how current project should be build.
# This file is handled by devy.sh script, more or less, in the same manner as:
#  - apache ant is handling build.xml
#  - apache maven is handling pom.xml
#  - gnu make is handling Makefile
#  - phing is handling build.xml
#  - devy.sh is handling devy-meta.sh 
#  - etc.
#
# We decided to use this script, instead of others, because we just wanted to:
#  - run drush easily
#  - handle overlays (ie. download archive, patch it, copy local
#    customizations and package/copy it under /var/www)
#  - easily extend it's features. (It's just a bash script)
#  - no dependencies. (It's just a bash script :) )
#
# If this requirements will grow, we'll take in consideration
# other more powerfull tools.
# 
# To build devy using this file please run:
#       cd /path/to/devy/
#       ./scripts/devy.sh --clean --build
#
# To package devy using this file please run:
#       cd /path/to/devy/
#       ./scripts/devy.sh --clean --package
# This command will generate:
#     - target/devy-drupal-{PACKAGE_VERSION}.tgz
#     - target/devy-magento-{PACKAGE_VERSION}.tgz
#     - target/devy-map-{PACKAGE_VERSION}.tgz
# To package devy with a specific version, 
# feel free to define PACKAGE_VERSION env var:
#     cd /path/to/devy/
#     env PACKAGE_VERSION="1.5.0" ./scripts/devy.sh --clean --package
# 
# For development, feel free to use --develop flag. It will create symbolic
# links between your dev files and build packages.
#       cd /path/to/devy/
#       ./scripts/devy.sh --clean --develop --install-www
#
# If you'd like to build devy under a different folder, feel free to point
# devy_BUILD_TARGET to a different location.
#       export devy_BUILD_TARGET='/home/devy/my-devy-build'
#       ./scripts/devy.sh --clean --develop --install-www
# Then all devy components will be found under my-devy-build folder,
# and /var/www will contain symliks pointing to that folder.
# ie. /var/www/drupal.content -> /home/devy/my-devy-build/drupal
#     /var/www/magento        -> /home/devy/my-devy-build/magento

PACKAGE_PREFIX=devy
[ -z "${PACKAGE_VERSION}" ] && PACKAGE_VERSION=trunk-$(date +%Y%m%d%H%M)

devy_BUILD_DRUSH_MAKE_FILE="${devy_HOME}/files/Makefile"
devy_BUILD_OVERLAY_DRUPAL="$(find ${devy_HOME}/patches/drupal/ -type f -name '*.patch') 
${devy_HOME}/drupal~"

devy_BUILD_OVERLAY_MAGENTO="svn:https://projects.optaros.com/svn/devy/magento-vanilla/magento-enterprise-1.9.0.0.tar.gz
$(find ${devy_HOME}/patches/magento/ -type f -name '*.patch')
${devy_HOME}/magento"

devy_BUILD_OVERLAY_MAP="${devy_HOME}/map-drupal"

# Installation target for each component
devy_INSTALL_WWW_DRUPAL="${devy_INSTALL_WEBDIR}/drupal.content"
devy_INSTALL_WWW_MAGENTO="${devy_INSTALL_WEBDIR}/magento"
devy_INSTALL_WWW_MAP="${devy_INSTALL_WEBDIR}/drupal.map"

# Which files should kept on each --install-www action
PERSIST_devy_INSTALL_WWW_DRUPAL="sites/default/settings.php sites/default/files"
PERSIST_devy_INSTALL_WWW_MAGENTO="app/etc/local.xml media"
PERSIST_devy_INSTALL_WWW_MAP="sites/default/settings.php sites/default/files"

# Hooks definition
HOOK_devy_BUILD_OVERLAYS_ITEM="devy_core_overlay_item"
HOOK_devy_BUILD_POST="devy_core_build_post"

function devy_core_overlay_item() {
  overlay=$1; target=$2

  devy_OVERLAY_PATCH_PNUM=0
  if [ -f ${overlay} -a "${overlay:${#overlay}-6}" == ".patch" \
       -a "$(dirname $overlay)" != "${devy_HOME}/patches/magento/support" ]; then
    # Devy patches are generated relativelly to devy root directory
    # while all other patches are created relativelly to component's
    # directory ie. magento support patches.
    devy_OVERLAY_PATCH_PNUM=1
  fi
  
  devy_overlay $overlay $target
}

function devy_core_build_post() {
  # Ported functions.rb's install_extras here.
  # Hopefully we'll be able to have at some point all
  # these actions handled by drupal_make.
  cp -a  ${devy_HOME}/solr/SolrPhpClient ${devy_BUILD_TARGET}/drupal/sites/all/modules/contrib/apachesolr/

  rm -rf "${devy_BUILD_TARGET}/drupal/sites/all/modules/custom/devy/fileframework/vendor/"
  mkdir -p "${devy_BUILD_TARGET}/drupal/sites/all/modules/custom/devy/fileframework/vendor"

  # download  and extract getId3() library (needed because drush_make 
  # is not extracting the correct content)
  getid3="getid3-1.7.9"
  url="http://netcologne.dl.sourceforge.net/project/getid3/getID3%28%29%201.x/1.7.9"
  wget -q ${url}/${getid3}.zip && unzip -q ${getid3}.zip -x -d ${devy_BUILD_TARGET}/drupal/sites/all/modules/custom/devy/fileframework/vendor/getid3
  # Remove creepy getid3 folder. 
  rm -rf ${devy_BUILD_TARGET}/drupal/sites/all/modules/custom/devy/fileframework/vendor/getid3/getid3/\!delete\ any\ module\ you\ don\'t\ like\,\ but\ check\ dependencies.txt/
  rm -rf ${getid3}.zip
  
  #rename flowplayer control to flowplayer.control.swf taking out the version number
  flowplayer_controls_version="3.2.0"
  mv "${devy_BUILD_TARGET}/drupal/sites/all/libraries/contrib/flowplayer/flowplayer.controls-${flowplayer_controls_version}.swf" \
  "${devy_BUILD_TARGET}/drupal/sites/all/modules/custom/devy/fileframework/vendor/flowplayer"

  mkdir -p ${devy_BUILD_TARGET}/drupal/sites/default/files/bitcache/file
  sudo chown -R www-data:www-data ${devy_BUILD_TARGET}/drupal/sites/default/files/bitcache/
  sudo chmod -R 777 ${devy_BUILD_TARGET}/drupal/sites/default/files/bitcache/

  # CAS build
  if [ -n "${CAS_BUILD}" ]; then  
    cd $devy_HOME/cas
    mvn clean package
    cp target/*.war ${devy_BUILD_TARGET}
  fi
}
