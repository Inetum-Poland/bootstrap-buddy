#!/bin/zsh

#
#  build.sh
#  Bootstrap Buddy
#
#  Copyright 2024 Inetum
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

cd "$(dirname "$0")"
xcodebuild -project "../Bootstrap Buddy/Bootstrap Buddy.xcodeproj" clean build analyze -configuration Release

echo; unset DECISION
echo -e "Would you like to notarize the bundle now? (y/n — no by default): \c"; read DECISION
if grep -iq 'y' <<< $DECISION; then
	"$(dirname "$0")/notarizeBundle.sh"
else
	echo; unset DECISION
	echo -e "Would you like to build a distribution package now? (y/n — no by default): \c"; read DECISION
	grep -iq 'y' <<< $DECISION && "$(dirname "$0")/pkg.sh"
fi