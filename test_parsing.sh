#!/usr/bin/env bash

# cub3D parsing test suite
# Usage:
#   bash test_parsing.sh
#   CUB=./cub3D TEX=./textures/Bricks_64.xpm bash test_parsing.sh
#
# Optional:
#   TIMEOUT=1        seconds allowed for a valid map to enter the game loop
#   VALGRIND=1       run invalid tests under valgrind too (if installed)
#
# Exit convention used by this tester:
#   INVALID case: program must terminate before TIMEOUT and print a line beginning with "Error"
#   VALID case:   program must not print a parsing error. It may:
#                 - keep running until timeout (normal mlx_loop), or
#                 - exit earlier because MLX/display is unavailable.
#
# The script creates temporary .cub files and deletes them at the end.

set -u

CUB="${CUB:-./cub3D}"
TEX="${TEX:-./textures/Bricks_64.xpm}"
TIMEOUT="${TIMEOUT:-1}"
VALGRIND="${VALGRIND:-0}"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cub3d_parser_tests.XXXXXX")"
OUT="$TMP_DIR/output.txt"

PASS=0
FAIL=0
SKIP=0
TOTAL=0

cleanup()
{
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

if [ ! -x "$CUB" ]; then
	echo "Error: executable not found or not executable: $CUB"
	echo "Build cub3D first, or run: CUB=/path/to/cub3D bash $0"
	exit 1
fi

if [ ! -f "$TEX" ]; then
	echo "Error: texture not found: $TEX"
	echo "Set TEX to an existing XPM file, for example:"
	echo "  TEX=./textures/Bricks_64.xpm bash $0"
	exit 1
fi

green='\033[0;32m'
red='\033[0;31m'
yellow='\033[0;33m'
reset='\033[0m'

record_pass()
{
	PASS=$((PASS + 1))
	printf "${green}PASS${reset}  %s\n" "$1"
}

record_fail()
{
	FAIL=$((FAIL + 1))
	printf "${red}FAIL${reset}  %s\n" "$1"
	if [ -s "$OUT" ]; then
		sed 's/^/      | /' "$OUT" | head -n 8
	fi
}

record_skip()
{
	SKIP=$((SKIP + 1))
	printf "${yellow}SKIP${reset}  %s\n" "$1"
}

write_base_config()
{
	cat <<EOF
NO $TEX
SO $TEX
WE $TEX
EA $TEX
F 220,100,0
C 225,30,0
EOF
}

write_valid_map()
{
	cat <<'EOF'
111111
100001
10N001
100001
111111
EOF
}

make_case()
{
	local file="$1"
	shift
	printf "%s" "$*" > "$file"
}

run_program()
{
	local file="$1"
	: > "$OUT"
	timeout "$TIMEOUT" "$CUB" "$file" >"$OUT" 2>&1
	return $?
}

contains_error()
{
	grep -q '^Error' "$OUT"
}

test_valid_file()
{
	local name="$1"
	local file="$2"
	local status

	TOTAL=$((TOTAL + 1))
	run_program "$file"
	status=$?

	# 124 means timeout: parser accepted file and MLX loop probably started.
	# A clean/early exit is also accepted if no "Error" was printed, useful in
	# environments where MLX cannot create a display.
	if contains_error; then
		record_fail "$name (expected VALID)"
	else
		record_pass "$name"
	fi
}

test_invalid_file()
{
	local name="$1"
	local file="$2"
	local status

	TOTAL=$((TOTAL + 1))
	run_program "$file"
	status=$?

	if [ "$status" -eq 124 ]; then
		record_fail "$name (expected ERROR, program kept running)"
	elif contains_error; then
		record_pass "$name"
	else
		record_fail "$name (expected ERROR output)"
	fi
}

test_invalid_arg()
{
	local name="$1"
	shift
	local status

	TOTAL=$((TOTAL + 1))
	: > "$OUT"
	timeout "$TIMEOUT" "$CUB" "$@" >"$OUT" 2>&1
	status=$?

	if [ "$status" -eq 124 ]; then
		record_fail "$name (expected ERROR, program kept running)"
	elif contains_error; then
		record_pass "$name"
	else
		record_fail "$name (expected ERROR output)"
	fi
}

make_valid()
{
	local file="$1"
	{
		write_base_config
		printf '\n'
		write_valid_map
	} > "$file"
}

section()
{
	echo
	echo "================================================================"
	echo "$1"
	echo "================================================================"
}

# --------------------------------------------------------------------------- #
section "1. ARGUMENTS AND .cub EXTENSION"

test_invalid_arg "No argument"
test_invalid_arg "Two map arguments" "a.cub" "b.cub"

for name in a ab abc map map.cu map.cube map.cubx map.txt map.CUB map.Cub map.cub.txt .cub; do
	test_invalid_arg "Invalid filename: $name" "$name"
done

# Existing valid filename test is covered below with generated *.cub files.

# --------------------------------------------------------------------------- #
section "2. BASIC VALID MAPS"

f="$TMP_DIR/basic.cub"
make_valid "$f"
test_valid_file "Basic valid map" "$f"

for dir in N S E W; do
	f="$TMP_DIR/player_${dir}.cub"
	{
		write_base_config
		printf '\n'
		printf '111\n1%s1\n111\n' "$dir"
	} > "$f"
	test_valid_file "Player direction $dir" "$f"
done

f="$TMP_DIR/no_blank_before_map.cub"
{
	write_base_config
	write_valid_map
} > "$f"
test_valid_file "No blank line required before map" "$f"

f="$TMP_DIR/many_blank_config.cub"
{
	printf '\n\n\n'
	printf 'C 225,30,0\n\n\n'
	printf 'EA %s\n\n' "$TEX"
	printf 'F 220,100,0\n\n\n'
	printf 'NO %s\n\n' "$TEX"
	printf 'WE %s\n\n\n' "$TEX"
	printf 'SO %s\n\n\n\n' "$TEX"
	write_valid_map
} > "$f"
test_valid_file "Config in arbitrary order with many blank lines" "$f"

f="$TMP_DIR/leading_spaces_map.cub"
{
	write_base_config
	printf '\n'
	cat <<'EOF'
   11111
   1N001
   11111
EOF
} > "$f"
test_valid_file "Leading spaces preserved in map" "$f"

f="$TMP_DIR/trailing_spaces_map.cub"
{
	write_base_config
	printf '\n'
	printf '11111   \n'
	printf '1N001   \n'
	printf '11111   \n'
} > "$f"
test_valid_file "Trailing spaces outside closed map" "$f"

f="$TMP_DIR/ragged_valid.cub"
{
	write_base_config
	printf '\n'
	cat <<'EOF'
    111111
    1N0001
111110001
100000001
111111111
EOF
} > "$f"
test_valid_file "Irregular/ragged but closed map" "$f"

f="$TMP_DIR/internal_walls.cub"
{
	write_base_config
	printf '\n'
	cat <<'EOF'
111111111
1N0010001
100010001
101110101
100000001
111111111
EOF
} > "$f"
test_valid_file "Internal walls and irregular rooms" "$f"

f="$TMP_DIR/player_isolated.cub"
{
	write_base_config
	printf '\n'
	cat <<'EOF'
11111
11N11
11111
EOF
} > "$f"
test_valid_file "Player enclosed directly by walls" "$f"

# No final newline.
f="$TMP_DIR/no_final_newline.cub"
{
	write_base_config
	printf '\n'
	printf '111111\n100001\n10N001\n100001\n111111'
} > "$f"
test_valid_file "Valid file without final newline" "$f"

# --------------------------------------------------------------------------- #
section "3. MISSING CONFIG ELEMENTS"

for missing in NO SO WE EA F C; do
	f="$TMP_DIR/missing_${missing}.cub"
	{
		[ "$missing" = "NO" ] || printf 'NO %s\n' "$TEX"
		[ "$missing" = "SO" ] || printf 'SO %s\n' "$TEX"
		[ "$missing" = "WE" ] || printf 'WE %s\n' "$TEX"
		[ "$missing" = "EA" ] || printf 'EA %s\n' "$TEX"
		[ "$missing" = "F"  ] || printf 'F 220,100,0\n'
		[ "$missing" = "C"  ] || printf 'C 225,30,0\n'
		printf '\n'
		write_valid_map
	} > "$f"
	test_invalid_file "Missing $missing" "$f"
done

f="$TMP_DIR/map_only.cub"
write_valid_map > "$f"
test_invalid_file "Map only, no configuration" "$f"

f="$TMP_DIR/config_only.cub"
write_base_config > "$f"
test_invalid_file "Configuration only, no map" "$f"

f="$TMP_DIR/empty.cub"
: > "$f"
test_invalid_file "Completely empty file" "$f"

f="$TMP_DIR/blank_only.cub"
printf '\n\n   \n\n' > "$f"
test_invalid_file "File containing only blank lines" "$f"

# --------------------------------------------------------------------------- #
section "4. DUPLICATE CONFIG ELEMENTS"

for duplicate in NO SO WE EA; do
	f="$TMP_DIR/dup_${duplicate}.cub"
	{
		write_base_config
		case "$duplicate" in
			NO) printf 'NO %s\n' "$TEX" ;;
			SO) printf 'SO %s\n' "$TEX" ;;
			WE) printf 'WE %s\n' "$TEX" ;;
			EA) printf 'EA %s\n' "$TEX" ;;
		esac
		printf '\n'
		write_valid_map
	} > "$f"
	test_invalid_file "Duplicate texture $duplicate" "$f"
done

for duplicate in F C; do
	f="$TMP_DIR/dup_${duplicate}.cub"
	{
		write_base_config
		printf '%s 1,2,3\n' "$duplicate"
		printf '\n'
		write_valid_map
	} > "$f"
	test_invalid_file "Duplicate color $duplicate" "$f"
done

# --------------------------------------------------------------------------- #
section "5. IDENTIFIERS AND UNKNOWN CONFIG"

declare -a bad_config_lines=(
	"N $TEX"
	"N0 $TEX"
	"NORTH $TEX"
	"S $TEX"
	"WEST $TEX"
	"E $TEX"
	"FF 1,2,3"
	"CC 1,2,3"
	"no $TEX"
	"No $TEX"
	"so $TEX"
	"f 1,2,3"
	"c 1,2,3"
	"HELLO"
	"X 123"
	"# comment"
	"// comment"
	"NO$TEX"
	"F1,2,3"
)

i=0
for bad in "${bad_config_lines[@]}"; do
	i=$((i + 1))
	f="$TMP_DIR/bad_identifier_${i}.cub"
	{
		printf '%s\n' "$bad"
		write_base_config
		printf '\n'
		write_valid_map
	} > "$f"
	test_invalid_file "Invalid/unknown config line: $bad" "$f"
done

# Leading whitespace before identifier: strict interpretation.
f="$TMP_DIR/leading_space_identifier.cub"
{
	printf ' NO %s\n' "$TEX"
	printf 'SO %s\nWE %s\nEA %s\nF 1,2,3\nC 4,5,6\n\n' "$TEX" "$TEX" "$TEX"
	write_valid_map
} > "$f"
test_invalid_file "Config identifier does not begin the line" "$f"

# --------------------------------------------------------------------------- #
section "6. TEXTURE PATH SYNTAX"

for id in NO SO WE EA; do
	f="$TMP_DIR/empty_${id}.cub"
	{
		case "$id" in
			NO) printf 'NO\nSO %s\nWE %s\nEA %s\n' "$TEX" "$TEX" "$TEX" ;;
			SO) printf 'NO %s\nSO\nWE %s\nEA %s\n' "$TEX" "$TEX" "$TEX" ;;
			WE) printf 'NO %s\nSO %s\nWE\nEA %s\n' "$TEX" "$TEX" "$TEX" ;;
			EA) printf 'NO %s\nSO %s\nWE %s\nEA\n' "$TEX" "$TEX" "$TEX" ;;
		esac
		printf 'F 1,2,3\nC 4,5,6\n\n'
		write_valid_map
	} > "$f"
	test_invalid_file "Missing path for $id" "$f"
done

f="$TMP_DIR/extra_texture_arg.cub"
{
	printf 'NO %s garbage\n' "$TEX"
	printf 'SO %s\nWE %s\nEA %s\nF 1,2,3\nC 4,5,6\n\n' "$TEX" "$TEX" "$TEX"
	write_valid_map
} > "$f"
test_invalid_file "Extra argument after texture path" "$f"

# A non-existent texture should be rejected at parser or texture-loading stage.
f="$TMP_DIR/missing_texture.cub"
{
	printf 'NO ./this_texture_definitely_does_not_exist.xpm\n'
	printf 'SO %s\nWE %s\nEA %s\nF 1,2,3\nC 4,5,6\n\n' "$TEX" "$TEX" "$TEX"
	write_valid_map
} > "$f"
test_invalid_file "Non-existent texture path" "$f"

# --------------------------------------------------------------------------- #
section "7. RGB VALID CASES"

declare -a good_rgbs=(
	"0,0,0"
	"255,255,255"
	"0,255,0"
	"255,0,255"
	"1,2,3"
	"01,002,003"
	"000,000,000"
	"1, 2, 3"
	"1 ,2 ,3"
	"1 , 2 , 3"
	"255 , 0 , 128"
)

i=0
for rgb in "${good_rgbs[@]}"; do
	i=$((i + 1))
	f="$TMP_DIR/good_rgb_${i}.cub"
	{
		printf 'NO %s\nSO %s\nWE %s\nEA %s\n' "$TEX" "$TEX" "$TEX" "$TEX"
		printf 'F %s\nC 10,20,30\n\n' "$rgb"
		write_valid_map
	} > "$f"
	test_valid_file "Valid RGB: F $rgb" "$f"
done

# --------------------------------------------------------------------------- #
section "8. RGB INVALID CASES"

declare -a bad_rgbs=(
	"256,0,0"
	"0,256,0"
	"0,0,256"
	"999,0,0"
	"-1,0,0"
	"0,-1,0"
	"0,0,-1"
	"1,2"
	"1"
	""
	"1,2,3,4"
	"1,2,3,"
	",1,2,3"
	",1,2"
	"1,,2"
	"1,2,"
	"a,2,3"
	"1,a,3"
	"1,2,a"
	"one,2,3"
	"1,2,3abc"
	"abc1,2,3"
	"1.0,2,3"
	"1,2.5,3"
	"+1,2,3"
	"0x10,20,30"
	"1,2,3 hello"
	"1,2,3x"
)

i=0
for rgb in "${bad_rgbs[@]}"; do
	i=$((i + 1))
	f="$TMP_DIR/bad_rgb_${i}.cub"
	{
		printf 'NO %s\nSO %s\nWE %s\nEA %s\n' "$TEX" "$TEX" "$TEX" "$TEX"
		printf 'F %s\nC 10,20,30\n\n' "$rgb"
		write_valid_map
	} > "$f"
	test_invalid_file "Invalid RGB: F $rgb" "$f"
done

f="$TMP_DIR/huge_rgb.cub"
{
	printf 'NO %s\nSO %s\nWE %s\nEA %s\n' "$TEX" "$TEX" "$TEX" "$TEX"
	printf 'F 999999999999999999999999999999,0,0\nC 1,2,3\n\n'
	write_valid_map
} > "$f"
test_invalid_file "Extremely large RGB integer" "$f"

# --------------------------------------------------------------------------- #
section "9. PLAYER COUNT"

f="$TMP_DIR/no_player.cub"
{
	write_base_config
	printf '\n'
	cat <<'EOF'
111111
100001
100001
111111
EOF
} > "$f"
test_invalid_file "No player" "$f"

declare -a double_maps=(
$'111111\n1N0S01\n111111\n'
$'111111\n1N0001\n100E01\n111111\n'
$'111111\n1N0W01\n100S01\n111111\n'
)

i=0
for m in "${double_maps[@]}"; do
	i=$((i + 1))
	f="$TMP_DIR/multi_player_${i}.cub"
	{
		write_base_config
		printf '\n%s' "$m"
	} > "$f"
	test_invalid_file "Multiple player markers #$i" "$f"
done

# --------------------------------------------------------------------------- #
section "10. INVALID MAP CHARACTERS"

declare -a bad_chars=("2" "3" "9" "X" "A" "n" "s" "e" "w" "." "-" "+" "#" "," "/")
i=0
for ch in "${bad_chars[@]}"; do
	i=$((i + 1))
	f="$TMP_DIR/bad_char_${i}.cub"
	{
		write_base_config
		printf '\n'
		printf '111111\n1N%s001\n111111\n' "$ch"
	} > "$f"
	test_invalid_file "Forbidden map character: $ch" "$f"
done

f="$TMP_DIR/tab_in_map.cub"
{
	write_base_config
	printf '\n'
	printf '111111\n1N0\t01\n111111\n'
} > "$f"
test_invalid_file "Tab inside map" "$f"

# --------------------------------------------------------------------------- #
section "11. OPEN / NOT-CLOSED MAPS"

declare -a open_maps=(
$'110111\n100001\n10N001\n100001\n111111\n'
$'111111\n100001\n10N001\n100001\n111011\n'
$'111111\n000001\n10N001\n100001\n111111\n'
$'111111\n100000\n10N001\n100001\n111111\n'
$'11N111\n100001\n100001\n111111\n'
$'111111\n100001\n100001\n111110\n'
$'111111\n1N0001\n110 11\n111111\n'
$'111111\n1 N001\n111111\n'
)

labels=(
	"Opening in top border"
	"Opening in bottom border"
	"Opening in left border"
	"Opening in right border"
	"Player on outer border"
	"Walkable 0 on outer border"
	"Void space adjacent to walkable cell"
	"Void space adjacent to player"
)

for i in "${!open_maps[@]}"; do
	f="$TMP_DIR/open_${i}.cub"
	{
		write_base_config
		printf '\n%s' "${open_maps[$i]}"
	} > "$f"
	test_invalid_file "${labels[$i]}" "$f"
done

f="$TMP_DIR/short_neighbor.cub"
{
	write_base_config
	printf '\n'
	cat <<'EOF'
111111
1N0001
11
EOF
} > "$f"
test_invalid_file "Very short neighboring row exposes floor" "$f"

f="$TMP_DIR/one_cell.cub"
{
	write_base_config
	printf '\nN\n'
} > "$f"
test_invalid_file "Map consisting of one player cell" "$f"

f="$TMP_DIR/one_row.cub"
{
	write_base_config
	printf '\n11N11\n'
} > "$f"
test_invalid_file "Single-row map" "$f"

f="$TMP_DIR/one_col.cub"
{
	write_base_config
	printf '\n1\n1\nN\n1\n1\n'
} > "$f"
test_invalid_file "Single-column map" "$f"

# --------------------------------------------------------------------------- #
section "12. MAP BLOCK MUST BE LAST AND CONTIGUOUS"

f="$TMP_DIR/split_map.cub"
{
	write_base_config
	printf '\n'
	cat <<'EOF'
111111
1N0001

100001
111111
EOF
} > "$f"
test_invalid_file "Empty line inside map block" "$f"

f="$TMP_DIR/config_after_map.cub"
{
	write_base_config
	printf '\n'
	write_valid_map
	printf 'NO %s\n' "$TEX"
} > "$f"
test_invalid_file "Config line after map" "$f"

f="$TMP_DIR/color_after_map.cub"
{
	printf 'NO %s\nSO %s\nWE %s\nEA %s\nF 1,2,3\n\n' "$TEX" "$TEX" "$TEX" "$TEX"
	write_valid_map
	printf 'C 4,5,6\n'
} > "$f"
test_invalid_file "Missing config field placed after map" "$f"

f="$TMP_DIR/map_before_config.cub"
{
	write_valid_map
	printf '\n'
	write_base_config
} > "$f"
test_invalid_file "Map before configuration" "$f"

f="$TMP_DIR/map_before_config_complete.cub"
{
	printf 'NO %s\nSO %s\nWE %s\nEA %s\nF 1,2,3\n\n' "$TEX" "$TEX" "$TEX" "$TEX"
	write_valid_map
} > "$f"
test_invalid_file "Map starts before all six config elements are present" "$f"

# --------------------------------------------------------------------------- #
section "13. STRESS / ROBUSTNESS"

# Very wide, closed map.
f="$TMP_DIR/very_wide.cub"
{
	write_base_config
	printf '\n'
	python3 - <<'PY'
w = 10000
print("1" * w)
print("1N" + "0" * (w - 3) + "1")
print("1" * w)
PY
} > "$f"
test_valid_file "Very wide map (10,000 columns)" "$f"

# Very tall, closed map.
f="$TMP_DIR/very_tall.cub"
{
	write_base_config
	printf '\n'
	python3 - <<'PY'
h = 1000
print("11111")
print("1N001")
for _ in range(h - 3):
    print("10001")
print("11111")
PY
} > "$f"
test_valid_file "Very tall map (1,000 rows)" "$f"

f="$TMP_DIR/random_ascii.cub"
{
	write_base_config
	printf '\n'
	printf '111111\n1N0001\n'
	python3 - <<'PY'
print("A!@#$%^&*()_+" * 100)
PY
	printf '111111\n'
} > "$f"
test_invalid_file "Long random invalid ASCII map line" "$f"

f="$TMP_DIR/ten_thousand_spaces.cub"
{
	write_base_config
	printf '\n'
	printf '111\n1N1\n111\n'
	python3 - <<'PY'
print(" " * 10000)
PY
} > "$f"
test_invalid_file "10,000-space line after map" "$f"

# --------------------------------------------------------------------------- #
section "14. OPTIONAL VALGRIND ON INVALID CASES"

if [ "$VALGRIND" = "1" ]; then
	if ! command -v valgrind >/dev/null 2>&1; then
		record_skip "Valgrind requested but not installed"
	else
		vg_cases=(
			"$TMP_DIR/missing_NO.cub"
			"$TMP_DIR/dup_NO.cub"
			"$TMP_DIR/bad_rgb_1.cub"
			"$TMP_DIR/no_player.cub"
			"$TMP_DIR/multi_player_1.cub"
			"$TMP_DIR/open_0.cub"
			"$TMP_DIR/split_map.cub"
			"$TMP_DIR/random_ascii.cub"
		)
		for f in "${vg_cases[@]}"; do
			TOTAL=$((TOTAL + 1))
			: > "$OUT"
			timeout "$((TIMEOUT + 2))" valgrind \
				--leak-check=full \
				--show-leak-kinds=all \
				--errors-for-leak-kinds=all \
				--error-exitcode=99 \
				"$CUB" "$f" >"$OUT" 2>&1
			status=$?
			if [ "$status" -eq 99 ]; then
				record_fail "Valgrind: $(basename "$f")"
			elif [ "$status" -eq 124 ]; then
				record_fail "Valgrind timeout: $(basename "$f")"
			else
				record_pass "Valgrind: $(basename "$f")"
			fi
		done
	fi
else
	record_skip "Valgrind tests disabled (run with VALGRIND=1)"
fi

# --------------------------------------------------------------------------- #
echo
echo "================================================================"
echo "RESULT"
echo "================================================================"
printf "Total executed: %d\n" "$TOTAL"
printf "${green}Passed: %d${reset}\n" "$PASS"
printf "${red}Failed: %d${reset}\n" "$FAIL"
printf "${yellow}Skipped: %d${reset}\n" "$SKIP"
echo

if [ "$FAIL" -eq 0 ]; then
	printf "${green}All executed parser tests passed.${reset}\n"
	exit 0
fi

printf "${red}%d test(s) failed.${reset}\n" "$FAIL"
exit 1
