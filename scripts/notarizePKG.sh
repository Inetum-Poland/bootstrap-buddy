#!/bin/zsh

#
#  notarizePKG.sh
#  Bootstrap Buddy
#
#  Copyright 2024 Inetum
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

clear

PKG_PATH="${1}"
if [[ -f "${PKG_PATH}" ]]; then
	PKG="${PKG_PATH}"
else
	echo -n "Drag’n’drop the .dmg or .pkg here: "
	read PKG
fi
PKG="${PKG/\ / }"
[[ ! -f "${PKG}" ]] && echo "Invalid path!" && exit 1

# NOTARIZATION: ————————————————————————————————————————————————————————————————
# xcrun notarytool store-credentials
# xcrun notarytool store-credentials ProfileName --key path_to_AuthKey_##########.p8 --key-id KEY_UD_HERE --issuer ISSUER_UUID_HERE
PROFILE="ProfileName"

xcrun notarytool submit ${PKG} --keychain-profile "${PROFILE}" --wait
echo "notarytool finished…"
sleep 2
xcrun notarytool info $(xcrun notarytool history --keychain-profile "${PROFILE}" | awk -F': ' '/id:/ {print $2;exit}') --keychain-profile "${PROFILE}"

# VALIDATION: ——————————————————————————————————————————————————————————————————
xcrun stapler staple "${PKG}"
stapler validate -v "${PKG}"

echo "Script finished."
exit 0