#!/bin/zsh

#
#  pkg.sh
#  Bootstrap Buddy
#
#  Copyright 2024 Inetum Poland
#
#  Based on Escrow Buddy
#  Copyright 2023 Netflix
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

# Fail script if any command fails
set -e

DEV_INSTALLER_CERT_CN="Developer ID Installer: Developer Name (TEAM_ID)"

cd "$(dirname "$0")"

echo "Determining version..."
VERSION=$(defaults read "$(pwd)/../Bootstrap Buddy/build/Release/Bootstrap Buddy.bundle/Contents/Info.plist" CFBundleShortVersionString)
echo "  Version: $VERSION"

echo "Preparing pkgroot and output folders..."
PKGROOT=$(mktemp -d /tmp/Bootstrap-Buddy-build-root-XXXXXXXXXXX)
OUTPUTDIR=$(mktemp -d /tmp/Bootstrap-Buddy-output-XXXXXXXXXXX)
mkdir -pv "${PKGROOT}/Library/Security/SecurityAgentPlugins/"

# echo "Copying bundle into pkgroot..."
cp -vR "../Bootstrap Buddy/build/Release/Bootstrap Buddy.bundle" "${PKGROOT}/Library/Security/SecurityAgentPlugins/Bootstrap Buddy.bundle"

echo "Building package..."
OUTFILE="${OUTPUTDIR}/Bootstrap Buddy-$VERSION.pkg"
pkgbuild --root "$PKGROOT" \
	--identifier com.inetum.Bootstrap-Buddy \
	--version "$VERSION" \
	--scripts pkg \
	"${OUTFILE}"

echo; unset DECISION
echo -e "Would you like to sign distribution package now? (y/n — no by default): \c"; read DECISION
if grep -iq 'y' <<< $DECISION; then
	echo -e "\nSigning distribution package…"
	productbuild --sign "${DEV_INSTALLER_CERT_CN}" --package "${OUTFILE}" "${OUTFILE%/*}/.tmp.pkg"
	ASK2NOTARIZE=true
else
	productbuild --package "${OUTFILE}" "${OUTFILE%/*}/.tmp.pkg"
	ASK2NOTARIZE=false
fi

rm -f "${OUTFILE}"
mv "${OUTFILE%/*}/.tmp.pkg" "${OUTFILE}"

echo "Done."
echo "${OUTFILE}"
open "${OUTPUTDIR}"

if $ASK2NOTARIZE; then
	echo; unset DECISION
	echo -e "Would you like to notarize distribution package now? (y/n — no by default): \c"; read DECISION
	grep -iq 'y' <<< $DECISION && "$(dirname "$0")/notarizePKG.sh"
fi
