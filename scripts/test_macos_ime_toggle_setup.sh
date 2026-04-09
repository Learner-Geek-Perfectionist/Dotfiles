#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./test_helpers.sh
source "$SCRIPT_DIR/test_helpers.sh"
# shellcheck source=./lib_macos_ime_toggle.sh
source "$SCRIPT_DIR/lib_macos_ime_toggle.sh"

assert_macos_ime_provider_contract() {
	local label="$1" expected_provider="$2" expected_wetype_source_id="$3" expected_english_source_id="$4" expected_chinese_source_id="$5" fixture_json="$6"
	local provider_info actual_provider actual_wetype_source_id actual_english_source_id actual_chinese_source_id

	provider_info="$(
		macos_select_ime_provider "$fixture_json"
	)"
	actual_provider="$(
		awk -F= '$1=="provider"{print $2}' <<<"$provider_info"
	)"
	actual_wetype_source_id="$(
		awk -F= '$1=="wetype_source_id"{print $2}' <<<"$provider_info"
	)"
	actual_english_source_id="$(
		awk -F= '$1=="english_source_id"{print $2}' <<<"$provider_info"
	)"
	actual_chinese_source_id="$(
		awk -F= '$1=="chinese_source_id"{print $2}' <<<"$provider_info"
	)"

	assert_equal "$expected_provider" "$actual_provider" "$label provider"
	assert_equal "$expected_wetype_source_id" "$actual_wetype_source_id" "$label wetype source"
	assert_equal "$expected_english_source_id" "$actual_english_source_id" "$label english source"
	assert_equal "$expected_chinese_source_id" "$actual_chinese_source_id" "$label chinese source"
}

test_macos_ime_toggle_setup() {
	local wetype_only_fixture
	local system_pair_only_fixture
	local system_pair_us_fixture
	local system_pair_both_english_fixture
	local mixed_install_fixture
	local english_only_fixture
	local chinese_only_fixture
	local empty_fixture

	wetype_only_fixture='[{"InputSourceKind":"Keyboard Input Method","Bundle ID":"com.tencent.inputmethod.wetype"},{"InputSourceKind":"Keyboard Layout","InputSourceID":"com.tencent.inputmethod.wetype.pinyin"}]'
	system_pair_only_fixture='[{"InputSourceKind":"Keyboard Layout","InputSourceID":"com.apple.keylayout.ABC"},{"InputSourceKind":"Keyboard Input Method","InputSourceID":"com.apple.inputmethod.SCIM.ITABC"}]'
	system_pair_us_fixture='[{"InputSourceKind":"Keyboard Layout","InputSourceID":"com.apple.keylayout.US"},{"InputSourceKind":"Keyboard Input Method","InputSourceID":"com.apple.inputmethod.SCIM.ITABC"}]'
	system_pair_both_english_fixture='[{"InputSourceKind":"Keyboard Layout","InputSourceID":"com.apple.keylayout.US"},{"InputSourceKind":"Keyboard Layout","InputSourceID":"com.apple.keylayout.ABC"},{"InputSourceKind":"Keyboard Input Method","InputSourceID":"com.apple.inputmethod.SCIM.ITABC"}]'
	mixed_install_fixture='[{"InputSourceKind":"Keyboard Layout","InputSourceID":"com.apple.keylayout.ABC"},{"InputSourceKind":"Keyboard Input Method","InputSourceID":"com.apple.inputmethod.SCIM.ITABC"},{"InputSourceKind":"Keyboard Input Method","Bundle ID":"com.tencent.inputmethod.wetype"},{"InputSourceKind":"Keyboard Layout","InputSourceID":"com.tencent.inputmethod.wetype.pinyin"}]'
	english_only_fixture='[{"InputSourceKind":"Keyboard Layout","InputSourceID":"com.apple.keylayout.US"}]'
	chinese_only_fixture='[{"InputSourceKind":"Keyboard Input Method","InputSourceID":"com.apple.inputmethod.SCIM.ITABC"}]'
	empty_fixture='[]'

	assert_macos_ime_provider_contract \
		"wetype only" \
		wetype \
		'com.tencent.inputmethod.wetype.pinyin' \
		'' \
		'' \
		"$wetype_only_fixture"
	assert_macos_ime_provider_contract \
		"system pair only" \
		apple_pair \
		'' \
		'com.apple.keylayout.ABC' \
		'com.apple.inputmethod.SCIM.ITABC' \
		"$system_pair_only_fixture"
	assert_macos_ime_provider_contract \
		"system pair US" \
		apple_pair \
		'' \
		'com.apple.keylayout.US' \
		'com.apple.inputmethod.SCIM.ITABC' \
		"$system_pair_us_fixture"
	assert_macos_ime_provider_contract \
		"system pair both english layouts prefers ABC" \
		apple_pair \
		'' \
		'com.apple.keylayout.ABC' \
		'com.apple.inputmethod.SCIM.ITABC' \
		"$system_pair_both_english_fixture"
	assert_macos_ime_provider_contract \
		"mixed install" \
		wetype \
		'com.tencent.inputmethod.wetype.pinyin' \
		'com.apple.keylayout.ABC' \
		'com.apple.inputmethod.SCIM.ITABC' \
		"$mixed_install_fixture"
	assert_macos_ime_provider_contract \
		"english only" \
		disabled \
		'' \
		'com.apple.keylayout.US' \
		'' \
		"$english_only_fixture"
	assert_macos_ime_provider_contract \
		"chinese only" \
		disabled \
		'' \
		'' \
		'com.apple.inputmethod.SCIM.ITABC' \
		"$chinese_only_fixture"
	assert_macos_ime_provider_contract \
		"empty fixture" \
		disabled \
		'' \
		'' \
		'' \
		"$empty_fixture"
}

test_macos_ime_toggle_setup
