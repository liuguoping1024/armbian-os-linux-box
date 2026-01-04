#!/bin/bash
#
# ThirdReality TRHub V3 Configuration Library
# Based on JetHub configuration
#

# Board identifier functions
get_board_model() {
	echo "ThirdReality TRHub V3"
}

get_board_variant() {
	echo "trhub-v3"
}

# W155S1 WiFi/BT support
has_w155s1_wifi() {
	return 0  # TRHub V3 has W155S1
}

has_w155s1_bt() {
	return 0  # TRHub V3 has W155S1 BT
}

# MAC address handling from efuse
get_mac_from_efuse() {
	local key_name="$1"
	if [ -f /sys/class/efuse/mac ]; then
		cat /sys/class/efuse/mac 2>/dev/null
	fi
}

# Serial number from efuse
get_serial_from_efuse() {
	if [ -f /sys/class/efuse/sn ]; then
		cat /sys/class/efuse/sn 2>/dev/null
	fi
}
