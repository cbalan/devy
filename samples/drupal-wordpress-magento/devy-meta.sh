#
# devy-meta.sh sample
#

PACKAGE_PREFIX=drupal-magento-devy-sample
[ -z "${PACKAGE_VERSION}" ] && PACKAGE_VERSION=$(date +%Y%m%d%H%M)

DEVY_BUILD_DRUSH_MAKE_FILE="${DEVY_HOME}/drupal/modules/drupal-magento-devy-sample.make"
DEVY_BUILD_OVERLAY_MAGENTO="svn:http://svn.magentocommerce.com/source/branches/1.4/ ${DEVY_HOME}/magento"

# Installation target for each component
DEVY_INSTALL_WWW_DRUPAL="${DEVY_INSTALL_WEBDIR}/devy-sample-drupal"
DEVY_INSTALL_WWW_MAGENTO="${DEVY_INSTALL_WEBDIR}/devy-sample-magento"