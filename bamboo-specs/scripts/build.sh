#!/bin/zsh -f
OUTDIR=Carthage
XCF_NAME=Sentry.xcframework
UPLOAD_PATH="https://art.int.agrd.dev/artifactory/adguard-pods/binaries/SentryCocoaMac"

# - Build
./scripts/build-xcframework.sh

# - Archive
VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString:" `find ${OUTDIR}/${XCF_NAME}  -path '*/Resources/Info.plist' | head -1`)
AG_VER="${1:-ag001}"
XCF_ARCHIVE_NAME=Sentry-${VER}-${AG_VER}.xcframework.zip

/usr/bin/ditto -c -k --keepParent "${OUTDIR}/${XCF_NAME}" \
    "${OUTDIR}/${XCF_ARCHIVE_NAME}" || exit

# - Upload to Artifactory
curl -u"${bamboo_artifactoryUser}":"${bamboo_artifactoryPassword}" \
    -XPUT "${UPLOAD_PATH}/${XCF_ARCHIVE_NAME}" \
    -T "${OUTDIR}/{$XCF_ARCHIVE_NAME}" \
    || exit

# - Create local artifact on Bamboo w/o version number
mv "${OUTDIR}/${XCF_ARCHIVE_NAME}" "${OUTDIR}/${XCF_NAME}.zip"
