#!/bin/bash

#
#  AuthDBSetup.sh
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

#  This script modifies the loginwindow authorization database to include a
#  line that invokes Bootstrap Buddy just prior to login process completion.
#  This line:
#      <string>Bootstrap Buddy:Invoke,privileged</string>
#  will be inserted just before this line:
#      <string>loginwindow:done</string>

echo "Checking execution context..."
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: The Bootstrap Buddy authorization database configuration script should be run as root."
    exit 1
fi

# Create temporary directory for storage of authorization database files
# Using hyphen to prevent escape issues in PlistBuddy commands
BB_DIR="${TMPDIR:=/private/tmp}/com.inetum.Bootstrap-Buddy"
mkdir -pv "$BB_DIR"
AUTH_DB="$BB_DIR/auth.db"

# Output current loginwindow auth database
echo "Reading system.login.console section of authorization database..."
/usr/bin/security authorizationdb read system.login.console > "$AUTH_DB"
if [[ ! -f "$AUTH_DB" ]]; then
    echo "ERROR: Unable to save the current authorization database."
    exit 1
fi

# Check current loginwindow auth database for desired entry
if grep -q '<string>Bootstrap Buddy:Invoke,privileged</string>' "$AUTH_DB"; then
    echo "Bootstrap Buddy is already configured in the loginwindow authorization database."
    rm -rf "$AUTH_DB"
    exit 0
fi

# Create a backup copy
cp "$AUTH_DB" "$AUTH_DB.backup"

echo "Adding Bootstrap Buddy to authorization database..."
INDEX=$(/usr/libexec/PlistBuddy -c "Print :mechanisms:" "$AUTH_DB" 2>/dev/null | grep -n "loginwindow:done" | awk -F ":" '{print $1}')
if [[ -z $INDEX ]]; then
    echo "ERROR: Unable to index current loginwindow authorization database."
    exit 1
fi

# Subtract 2 from the index to account for PlistBuddy output format
INDEX=$((INDEX-2))

# Insert Bootstrap Buddy mechanism one line before loginwindow:done
/usr/libexec/PlistBuddy -c "Add :mechanisms:$INDEX string 'Bootstrap Buddy:Invoke,privileged'" "$AUTH_DB"

# Save authorization database changes
if ! security authorizationdb write system.login.console < "$AUTH_DB"; then
    echo "ERROR: Unable to save changes to authorization database."
    exit 1
fi

echo "Bootstrap Buddy successfully configured in macOS authorization database."
