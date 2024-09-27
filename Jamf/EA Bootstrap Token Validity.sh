#!/bin/zsh

#
#  EA Bootstrap Token Validity.sh
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

EACS_STATUS="$(/usr/libexec/mdmclient QueryDeviceInformation | awk -F'= |;' '/EACS/ {print $2}')"
if [[ -z "${EACS_STATUS}" ]]; then
	echo "<result>N/A</result>"
elif [[ "${EACS_STATUS}" == "success" ]]; then
	echo "<result>Valid</result>"
else
	echo "<result>Invalid (${EACS_STATUS//\"/})</result>"
fi

exit 0