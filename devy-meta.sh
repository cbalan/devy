#
# devy-meta.sh sample
#

PACKAGE_PREFIX=cool-scripting-project
[ -z "${PACKAGE_VERSION}" ] && PACKAGE_VERSION=trunk-$(date +%Y%m%d%H%M)

DEVY_BUILD_DRUSH_MAKE_FILE="${DEVY_HOME}/drupal/modules/cool.make"
DEVY_BUILD_OVERLAY_DRUPAL="$(find ${DEVY_HOME}/patches/drupal/ -type f -name '*.patch') 
${DEVY_HOME}/drupal~"

DEVY_BUILD_OVERLAY_MAGENTO="svn:http://svn.magentocommerce.com/source/branches/1.4/
$(find ${DEVY_HOME}/patches/magento/ -type f -name '*.patch')
${DEVY_HOME}/magento"

DEVY_BUILD_OVERLAY_MAP="${DEVY_HOME}/map-drupal"

# Installation target for each component
DEVY_INSTALL_WWW_DRUPAL="${DEVY_INSTALL_WEBDIR}/drupal.content"
DEVY_INSTALL_WWW_MAGENTO="${DEVY_INSTALL_WEBDIR}/magento"

# Which files should kept on each --install-www action
PERSIST_DEVY_INSTALL_WWW_DRUPAL="sites/default/settings.php sites/default/files"
PERSIST_DEVY_INSTALL_WWW_MAGENTO="app/etc/local.xml media"
PERSIST_DEVY_INSTALL_WWW_MAP="sites/default/settings.php sites/default/files"

# Hooks definition
HOOK_DEVY_BUILD_POST="devy_core_build_post"

function devy_core_build_post() {
  echo "Devy build done."
}
