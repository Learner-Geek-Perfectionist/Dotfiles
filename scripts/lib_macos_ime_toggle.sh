#!/bin/bash

set -euo pipefail

MACOS_WETYPE_SOURCE_ID="com.tencent.inputmethod.wetype.pinyin"
MACOS_APPLE_CHINESE_SOURCE_ID="com.apple.inputmethod.SCIM.ITABC"
MACOS_APPLE_ENGLISH_SOURCE_IDS=(
	"com.apple.keylayout.ABC"
	"com.apple.keylayout.US"
)
MACOS_KARABINER_APPLE_BASELINE_KEY_CODE="spacebar"
MACOS_KARABINER_APPLE_BASELINE_MODIFIER="left_control"
MACOS_KARABINER_DISABLED_CAPS_RULE_DESCRIPTION="Keep caps lock as left_shift fallback"

macos_read_hitoolbox_provider_state_json() {
	local hitoolbox_plist="$1"
	local enabled_sources_json="[]"
	local selected_sources_json="[]"
	local history_sources_json="[]"
	local current_layout_id=""
	local current_layout_json="null"

	if command -v python3 &>/dev/null; then
		if python3 - "$hitoolbox_plist" <<'PY' 2>/dev/null
import json
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    data = plistlib.load(handle)

subset = {
    "AppleCurrentKeyboardLayoutInputSourceID": data.get("AppleCurrentKeyboardLayoutInputSourceID"),
    "AppleEnabledInputSources": data.get("AppleEnabledInputSources", []),
    "AppleInputSourceHistory": data.get("AppleInputSourceHistory", []),
    "AppleSelectedInputSources": data.get("AppleSelectedInputSources", []),
}

print(json.dumps(subset, ensure_ascii=False))
PY
		then
			return 0
		fi
	fi

	enabled_sources_json="$(
		plutil -extract AppleEnabledInputSources json -o - "$hitoolbox_plist" 2>/dev/null || printf '[]'
	)"
	selected_sources_json="$(
		plutil -extract AppleSelectedInputSources json -o - "$hitoolbox_plist" 2>/dev/null || printf '[]'
	)"
	history_sources_json="$(
		plutil -extract AppleInputSourceHistory json -o - "$hitoolbox_plist" 2>/dev/null || printf '[]'
	)"
	current_layout_id="$(
		plutil -extract AppleCurrentKeyboardLayoutInputSourceID raw -o - "$hitoolbox_plist" 2>/dev/null || true
	)"

	if [[ -n "$current_layout_id" ]]; then
		current_layout_json="$(
			printf '%s' "$current_layout_id" | sed 's/\\/\\\\/g; s/"/\\"/g; 1s/^/"/; $s/$/"/'
		)"
	fi

	printf '{"AppleCurrentKeyboardLayoutInputSourceID":%s,"AppleEnabledInputSources":%s,"AppleInputSourceHistory":%s,"AppleSelectedInputSources":%s}\n' \
		"${current_layout_json:-null}" \
		"$enabled_sources_json" \
		"$history_sources_json" \
		"$selected_sources_json"
}

macos_extract_input_source_ids() {
	local hitoolbox_json="$1"
	local parsed_ids=""

	if command -v jq &>/dev/null; then
		if parsed_ids="$(
			jq -r '
				def source_values:
					.. | objects | .["InputSourceID"]?, .["Input Mode"]? | select(. != null and . != "");
				if type == "array" then
					source_values
				elif type == "object" then
					.["AppleCurrentKeyboardLayoutInputSourceID"]?,
					source_values
				else
					empty
				end
			' <<<"$hitoolbox_json" 2>/dev/null
		)"; then
			printf '%s\n' "$parsed_ids"
			return 0
		fi
	fi

	if command -v python3 &>/dev/null; then
		if parsed_ids="$(
			python3 -c '
import json
import sys

def emit_ids(node):
    if isinstance(node, dict):
        current_layout = node.get("AppleCurrentKeyboardLayoutInputSourceID")
        if current_layout:
            print(current_layout)
        for key in ("InputSourceID", "Input Mode"):
            value = node.get(key)
            if value:
                print(value)
        for value in node.values():
            emit_ids(value)
    elif isinstance(node, list):
        for item in node:
            emit_ids(item)

emit_ids(json.load(sys.stdin))
' <<<"$hitoolbox_json" 2>/dev/null
		)"; then
			printf '%s\n' "$parsed_ids"
			return 0
		fi
	fi

	grep -oE '"(InputSourceID|Input Mode|AppleCurrentKeyboardLayoutInputSourceID)"[[:space:]]*:[[:space:]]*"[^"]*"' <<<"$hitoolbox_json" \
		| sed 's/^.*:[[:space:]]*"//; s/"$//' \
		|| true
}

macos_select_ime_provider() {
	local hitoolbox_json="$1"
	local input_source_ids
	local wetype_source_id=""
	local english_source_id=""
	local chinese_source_id=""
	local provider="disabled"
	local input_source_id
	local english_candidate

	input_source_ids="$(
		macos_extract_input_source_ids "$hitoolbox_json"
	)"

	while IFS= read -r input_source_id; do
		[[ -n "$input_source_id" ]] || continue
		if [[ "$input_source_id" == "$MACOS_WETYPE_SOURCE_ID" ]]; then
			wetype_source_id="$input_source_id"
		fi
		if [[ "$input_source_id" == "$MACOS_APPLE_CHINESE_SOURCE_ID" ]]; then
			chinese_source_id="$input_source_id"
		fi
	done <<<"$input_source_ids"

	for english_candidate in "${MACOS_APPLE_ENGLISH_SOURCE_IDS[@]}"; do
		if grep -Fxq "$english_candidate" <<<"$input_source_ids"; then
			english_source_id="$english_candidate"
			break
		fi
	done

	if [[ -n "$wetype_source_id" ]]; then
		provider="wetype"
	elif [[ -n "$english_source_id" && -n "$chinese_source_id" ]]; then
		provider="apple_pair"
	fi

	printf 'provider=%s\n' "$provider"
	printf 'wetype_source_id=%s\n' "$wetype_source_id"
	printf 'english_source_id=%s\n' "$english_source_id"
	printf 'chinese_source_id=%s\n' "$chinese_source_id"
}

macos_customize_home_karabiner_config() {
	local target="$1" provider="$2" tmp

	[[ -f "$target" ]] || return 1
	case "$provider" in
	apple_pair | wetype | disabled) ;;
	*)
		return 1
		;;
	esac

	tmp=$(mktemp)
	if ! perl -MJSON::PP - "$provider" "$target" \
		"$MACOS_KARABINER_DISABLED_CAPS_RULE_DESCRIPTION" \
		"$MACOS_KARABINER_APPLE_BASELINE_KEY_CODE" \
		"$MACOS_KARABINER_APPLE_BASELINE_MODIFIER" >"$tmp" <<'PERL'
use strict;
use warnings;
use JSON::PP qw(decode_json);

my (
	$provider,
	$target,
	$disabled_caps_rule_description,
	$baseline_key_code,
	$baseline_modifier,
) = @ARGV;

open my $fh, '<', $target or die "failed to open $target: $!";
local $/;
my $json = <$fh>;
close $fh;
binmode STDOUT, ':encoding(UTF-8)';

my $data = decode_json($json);
my $rules = $data->{profiles}[0]{complex_modifications}{rules};
my @patched_rules;

sub manipulator_matches_click_shape {
	my ($manipulator, $from_key, $to_key, $to_if_alone_kind) = @_;

	return 0 unless ref($manipulator) eq 'HASH';
	return 0 unless ($manipulator->{type} // q{}) eq 'basic';
	return 0 unless ref($manipulator->{from}) eq 'HASH';
	return 0 unless ($manipulator->{from}{key_code} // q{}) eq $from_key;

	my $optional = $manipulator->{from}{modifiers}{optional} // [];
	return 0 unless ref($optional) eq 'ARRAY' && @{$optional} == 1 && $optional->[0] eq 'any';
	return 0 unless (($manipulator->{parameters} // {})->{'basic.to_if_alone_timeout_milliseconds'} // 0) == 200;

	my $to = $manipulator->{to} // [];
	return 0 unless ref($to) eq 'ARRAY' && @{$to} == 1;
	return 0 unless ref($to->[0]) eq 'HASH';
	return 0 unless ($to->[0]{key_code} // q{}) eq $to_key;
	return 0 unless $to->[0]{lazy};

	my $to_if_alone = $manipulator->{to_if_alone} // [];
	return 0 unless ref($to_if_alone) eq 'ARRAY' && @{$to_if_alone} == 1;
	return 0 unless ref($to_if_alone->[0]) eq 'HASH';

	if ($to_if_alone_kind eq 'control_space') {
		return 0 unless keys(%{$to_if_alone->[0]}) == 2;
		return 0 unless ($to_if_alone->[0]{key_code} // q{}) eq $baseline_key_code;
		my $modifiers = $to_if_alone->[0]{modifiers} // [];
		return 0 unless ref($modifiers) eq 'ARRAY' && @{$modifiers} == 1 && $modifiers->[0] eq $baseline_modifier;
		return 1;
	}

	if ($to_if_alone_kind eq 'key_code') {
		return 0 unless keys(%{$to_if_alone->[0]}) == 1;
		return 0 unless ($to_if_alone->[0]{key_code} // q{}) eq 'left_shift';
		return 1;
	}

	die "unexpected click-rule kind $to_if_alone_kind";
}

sub find_unique_click_rule_index {
	my ($rules, $from_key, $to_key, $to_if_alone_kind, $target) = @_;
	my @matches;

	for my $index (0 .. $#{$rules}) {
		my $rule = $rules->[$index];
		next unless ref($rule->{manipulators}) eq 'ARRAY' && @{ $rule->{manipulators} } == 1;
		next unless manipulator_matches_click_shape($rule->{manipulators}[0], $from_key, $to_key, $to_if_alone_kind);
		push @matches, $index;
	}

	die "expected exactly one IME click rule for $from_key in $target" unless @matches == 1;
	return $matches[0];
}

my %ime_click_rule_indices = (
	left_shift => find_unique_click_rule_index($rules, 'left_shift', 'left_shift', 'control_space', $target),
	right_shift => find_unique_click_rule_index($rules, 'right_shift', 'right_shift', 'control_space', $target),
	caps_lock => find_unique_click_rule_index($rules, 'caps_lock', 'left_shift', 'control_space', $target),
);
my %rewritten_click_rules;

for my $index (0 .. $#{$rules}) {
	my $rule = $rules->[$index];

	if ($provider eq 'disabled') {
		if ($index == $ime_click_rule_indices{caps_lock}) {
			my ($caps_manipulator) = @{ $rule->{manipulators} // [] };
			die "failed to build caps fallback from malformed IME click rule in $target" unless ref($caps_manipulator) eq 'HASH';

			my %fallback_manipulator = %{$caps_manipulator};
			delete $fallback_manipulator{to_if_alone};
			delete $fallback_manipulator{parameters};
			push @patched_rules, {
				description => $disabled_caps_rule_description,
				manipulators => [\%fallback_manipulator],
			};
			next;
		}

		next if $index == $ime_click_rule_indices{left_shift};
		next if $index == $ime_click_rule_indices{right_shift};
		next if $index == $ime_click_rule_indices{caps_lock};
	}

	if ($provider eq 'wetype') {
		my ($from_key) = grep { $index == $ime_click_rule_indices{$_} } keys %ime_click_rule_indices;
		if (defined $from_key) {
			my ($manipulator) = @{ $rule->{manipulators} // [] };
			die "failed to find wetype click rule for $from_key in $target" unless manipulator_matches_click_shape($manipulator, $from_key, ($from_key eq 'caps_lock' ? 'left_shift' : $from_key), 'control_space');

			$manipulator->{to_if_alone}[0] = { key_code => 'left_shift' };
			$rewritten_click_rules{$from_key} = 1;
		}
	}

	push @patched_rules, $rule;
}

if ($provider eq 'wetype') {
	for my $key (qw(left_shift right_shift caps_lock)) {
		die "failed to rewrite wetype click rule for $key in $target" unless $rewritten_click_rules{$key};
	}
} elsif ($provider eq 'disabled') {
} elsif ($provider eq 'apple_pair') {
} else {
	die "unexpected provider $provider";
}

$data->{profiles}[0]{complex_modifications}{rules} = \@patched_rules;
print JSON::PP->new->canonical->pretty->encode($data);
PERL
	then
		rm -f "$tmp"
		return 1
	fi

	mv "$tmp" "$target"
}
