#!/usr/bin/env bash
# Read-only triage report for upstream changes in 102sdp and sdp-pusat-legacy.
# Reads watermarks and watchlists from scripts/legacy-watch.conf.
# Compatible with macOS bash 3.2.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
CONF_FILE="$ROOT_DIR/scripts/legacy-watch.conf"

DO_FETCH=0
SHOW_DIFF=0
FILTER_REPO=""
FROM_OVERRIDE=""

usage() {
	cat <<'EOF'
Usage: ./scripts/triage-legacy.sh [options]

Inspect upstream legacy changes since the recorded watermark in scripts/legacy-watch.conf
and group them into Buckets 1-5 (Schema/SQL, Shared Core, Ported Slices, Indirect Hits,
Cutover Conflict Preview).

Options:
  --fetch          Run `git fetch origin` in selected legacy repo(s) before diffing
  --repo <name>    Only inspect one repo from legacy-watch.conf (102sdp | pusat)
  --from <sha>     Override watermark SHA (requires --repo)
  --diff           Print whitespace-clean diffs for flagged Buckets 1-3 & indirect samples
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--fetch) DO_FETCH=1 ;;
		--diff) SHOW_DIFF=1 ;;
		--repo)
			shift
			[[ $# -gt 0 ]] || { echo "Missing value for --repo" >&2; exit 1; }
			FILTER_REPO="$1"
			;;
		--from)
			shift
			[[ $# -gt 0 ]] || { echo "Missing value for --from" >&2; exit 1; }
			FROM_OVERRIDE="$1"
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
	esac
	shift
done

if [[ -n "$FROM_OVERRIDE" && -z "$FILTER_REPO" ]]; then
	echo "--from requires --repo <name>" >&2
	exit 1
fi

if [[ ! -f "$CONF_FILE" ]]; then
	echo "Missing config file: $CONF_FILE" >&2
	exit 1
fi

TMPDIR_TRIAGE="$(mktemp -d "${TMPDIR:-/tmp}/sdp-triage.XXXXXX")"
cleanup() {
	rm -rf "$TMPDIR_TRIAGE"
}
trap cleanup EXIT

REPOS_FILE="$TMPDIR_TRIAGE/repos.tsv"
SHARED_FILE="$TMPDIR_TRIAGE/shared.list"
SLICE_FILE="$TMPDIR_TRIAGE/slices.tsv"
PATTERNS_FILE="$TMPDIR_TRIAGE/patterns.tsv"
TABLES_LIST="$TMPDIR_TRIAGE/tables.list"

: >"$REPOS_FILE"
: >"$SHARED_FILE"
: >"$SLICE_FILE"
: >"$PATTERNS_FILE"
: >"$TABLES_LIST"

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
	case "$raw_line" in
		""|\#*) continue ;;
	esac
	IFS='|' read -r kind f1 f2 f3 f4 f5 <<EOF
$raw_line
EOF
	case "$kind" in
		repo)
			printf '%s\t%s\t%s\t%s\t%s\n' "$f1" "$f2" "$f3" "$f4" "$f5" >>"$REPOS_FILE"
			;;
		shared)
			printf '%s\n' "$f1" >>"$SHARED_FILE"
			;;
		slice)
			printf '%s\t%s\n' "$f1" "$f2" >>"$SLICE_FILE"
			;;
		table)
			printf 'table\t%s\t%s\n' "$f1" "$f2" >>"$PATTERNS_FILE"
			printf '%s\n' "$f2" >>"$TABLES_LIST"
			;;
		url)
			printf 'url\t%s\t%s\n' "$f1" "$f2" >>"$PATTERNS_FILE"
			;;
		*)
			echo "Warning: unknown record type '$kind' in $CONF_FILE" >&2
			;;
	esac
done <"$CONF_FILE"

match_glob_file() {
	local path="$1"
	local file="$2"
	local pat
	while IFS= read -r pat || [[ -n "$pat" ]]; do
		[[ -n "$pat" ]] || continue
		# shellcheck disable=SC2254
		case "$path" in
			$pat) return 0 ;;
		esac
	done <"$file"
	return 1
}

match_slice_file() {
	local path="$1"
	local file="$2"
	local sname pat
	while IFS=$'\t' read -r sname pat || [[ -n "$sname" ]]; do
		[[ -n "$sname" ]] || continue
		# shellcheck disable=SC2254
		case "$path" in
			$pat)
				printf '%s' "$sname"
				return 0
				;;
		esac
	done <"$file"
	return 1
}

print_list_file() {
	local file="$1"
	local indent="${2:-  }"
	if [[ ! -s "$file" ]]; then
		printf '%s(none)\n' "$indent"
		return 0
	fi
	while IFS= read -r line || [[ -n "$line" ]]; do
		printf '%s%s\n' "$indent" "$line"
	done <"$file"
}

run_repo_triage() {
	local name="$1"
	local rel_dir="$2"
	local upstream_ref="$3"
	local watermark="$4"
	local local_branch="$5"
	local repo_dir="$ROOT_DIR/$rel_dir"

	if [[ -n "$FROM_OVERRIDE" ]]; then
		watermark="$FROM_OVERRIDE"
	fi

	if [[ ! -d "$repo_dir/.git" ]]; then
		echo "=== $name ($upstream_ref) ==="
		echo "Missing git repo at $repo_dir"
		echo ""
		return 0
	fi

	if (( DO_FETCH )); then
		echo "[fetch] $name ($rel_dir)..."
		git -C "$repo_dir" fetch origin
	fi

	if ! git -C "$repo_dir" rev-parse --verify "${watermark}^{commit}" >/dev/null 2>&1; then
		echo "Invalid watermark ref '$watermark' in $repo_dir" >&2
		return 1
	fi
	if ! git -C "$repo_dir" rev-parse --verify "${upstream_ref}^{commit}" >/dev/null 2>&1; then
		echo "Invalid upstream ref '$upstream_ref' in $repo_dir" >&2
		return 1
	fi

	local short_wm short_up commit_count
	short_wm="$(git -C "$repo_dir" rev-parse --short "$watermark")"
	short_up="$(git -C "$repo_dir" rev-parse --short "$upstream_ref")"
	commit_count="$(git -C "$repo_dir" rev-list --count "$watermark..$upstream_ref")"

	echo "=== $name ($upstream_ref vs $local_branch) ==="
	if [[ "$commit_count" == "0" ]]; then
		echo "Up to date (0 new commits since $short_wm)."
		echo ""
		return 0
	fi

	local oldest_date newest_date
	oldest_date="$(git -C "$repo_dir" log --reverse --format=%cs "$watermark..$upstream_ref" | head -n 1 || true)"
	newest_date="$(git -C "$repo_dir" log -n 1 --format=%cs "$upstream_ref" || true)"

	local work="$TMPDIR_TRIAGE/$name"
	rm -rf "$work"
	mkdir -p "$work"

	git -C "$repo_dir" diff --name-status "$watermark..$upstream_ref" >"$work/changed.tsv"
	local total_files
	total_files="$(wc -l <"$work/changed.tsv" | tr -d ' ')"

	echo "Range: $short_wm..$short_up ($commit_count commits, $oldest_date .. $newest_date), $total_files files changed"
	echo ""

	local b1_disp="$work/b1.disp" b1_paths="$work/b1.paths" b1_pairs="$work/b1.pairs"
	local b2_disp="$work/b2.disp" b2_paths="$work/b2.paths"
	local b3_disp="$work/b3.disp" b3_paths="$work/b3.paths"
	local unp_map="$work/unported.tsv" all_paths="$work/all.paths"
	: >"$b1_disp"; : >"$b1_paths"; : >"$b1_pairs"
	: >"$b2_disp"; : >"$b2_paths"
	: >"$b3_disp"; : >"$b3_paths"
	: >"$unp_map"; : >"$all_paths"

	local unported_total=0
	local status p1 p2 check_path disp slice_hit

	while IFS=$'\t' read -r status p1 p2 || [[ -n "$status" ]]; do
		[[ -n "$status" ]] || continue
		if [[ -n "${p2:-}" ]]; then
			check_path="$p2"
			disp="$status  $p1 -> $p2"
			printf '%s\n%s\n' "$p1" "$p2" >>"$all_paths"
		else
			check_path="$p1"
			disp="$status  $p1"
			printf '%s\n' "$p1" >>"$all_paths"
		fi

		case "$check_path" in
			querybox/*|*.sql)
				printf '%s\n' "$disp" >>"$b1_disp"
				printf '%s\n' "$check_path" >>"$b1_paths"
				if [[ -n "${p2:-}" ]]; then
					printf '%s\n' "$p1" >>"$b1_paths"
					printf '%s\t%s\n' "$p2" "$p1" >>"$b1_pairs"
				else
					printf '%s\t\n' "$p1" >>"$b1_pairs"
				fi
				continue
				;;
		esac

		if match_glob_file "$check_path" "$SHARED_FILE"; then
			printf '%s\n' "$disp" >>"$b2_disp"
			printf '%s\n' "$check_path" >>"$b2_paths"
			[[ -n "${p2:-}" ]] && printf '%s\n' "$p1" >>"$b2_paths"
			continue
		fi

		if slice_hit="$(match_slice_file "$check_path" "$SLICE_FILE")"; then
			printf '[%s] %s\n' "$slice_hit" "$disp" >>"$b3_disp"
			printf '%s\n' "$check_path" >>"$b3_paths"
			[[ -n "${p2:-}" ]] && printf '%s\n' "$p1" >>"$b3_paths"
			continue
		fi

		unported_total=$((unported_total + 1))
		printf '%s\t%s\n' "$check_path" "$disp" >>"$unp_map"
		if [[ -n "${p2:-}" ]]; then
			printf '%s\t%s\n' "$p1" "$disp" >>"$unp_map"
		fi
	done <"$work/changed.tsv"

	# Bucket 1: Schema / SQL
	echo "[Bucket 1] Schema / SQL"
	print_list_file "$b1_disp" "  "
	if [[ -s "$b1_paths" ]]; then
		local -a sql_args=()
		while IFS= read -r p || [[ -n "$p" ]]; do
			[[ -n "$p" ]] && sql_args+=("$p")
		done <"$b1_paths"
		if [[ ${#sql_args[@]} -gt 0 ]]; then
			local ddl_out="$work/b1_ddl.txt"
			git -C "$repo_dir" diff -w --ignore-cr-at-eol -U0 "$watermark..$upstream_ref" -- "${sql_args[@]}" | \
				awk -v tfile="$TABLES_LIST" '
				BEGIN {
					n_tbl = 0;
					while ((getline t < tfile) > 0) {
						if (t != "") {
							n_tbl++;
							tbl[n_tbl] = tolower(t);
						}
					}
					close(tfile);
					cur = "";
				}
				/^\+\+\+ b\// { cur = substr($0, 7); next; }
				/^\+\+\+ / { next; }
				/^\+/ {
					raw = substr($0, 2);
					low = tolower(raw);
					if (low ~ /^[ \t]*(create[ \t]+(or[ \t]+replace[ \t]+)?table|alter[ \t]+table|drop[ \t]+table)/ ||
					    (low ~ /(insert|replace|update)[ \t]+/ && low ~ /(daftar_referensi|menu)/)) {
						owned = "";
						if (low ~ /(create|alter|drop)[ \t]+.*table/) {
							for (i = 1; i <= n_tbl; i++) {
								if (low ~ ("(^|[^a-z0-9_])" tbl[i] "([^a-z0-9_]|$)")) {
									owned = owned " [OWNED TABLE: " tbl[i] "]";
								}
							}
						}
						snippet = raw;
						gsub(/^[ \t]+/, "", snippet);
						if (length(snippet) > 130) snippet = substr(snippet, 1, 127) "...";
						printf "    * %s:%s +%s\n", cur, owned, snippet;
					}
				}' >"$ddl_out" || true
			if [[ -s "$ddl_out" ]]; then
				echo "  DDL / metadata highlights:"
				cat "$ddl_out"
			fi
		fi
	fi
	echo ""

	# Bucket 2: Shared Core
	echo "[Bucket 2] Shared Core / Auth / RBAC / Shell"
	print_list_file "$b2_disp" "  "
	echo ""

	# Bucket 3: Ported & In-Progress Slices
	echo "[Bucket 3] Ported & In-Progress Slices"
	print_list_file "$b3_disp" "  "
	echo ""

	# Bucket 4: Indirect hits on unported files
	echo "[Bucket 4] Indirect Hits (Unported files referencing owned tables / cutover URLs)"
	local hit_count=0
	local b4_samples="$work/b4_samples.txt"
	: >"$b4_samples"
	if (( unported_total > 0 )); then
		local b4_report="$work/b4_report.txt"
		git -C "$repo_dir" diff -w --ignore-cr-at-eol -U0 "$watermark..$upstream_ref" -- ':(exclude)*.sql' ':(exclude)querybox/*' | \
			awk -v ufile="$unp_map" -v pfile="$PATTERNS_FILE" -v sfile="$b4_samples" -v cfile="$work/b4_count.txt" '
			BEGIN {
				sq = sprintf("%c", 39);
				dq = sprintf("%c", 34);
				bt = sprintf("%c", 96);
				sep = "[ \t(" sq dq bt "]+";
				endb = "([^a-z0-9_]|$)";
				kw = "(^|[^a-z0-9_])(from|join|into|update|table|get|get_where|insert|delete|replace|alter)";

				while ((getline line < ufile) > 0) {
					split(line, cols, "\t");
					if (cols[1] != "") {
						if (!(cols[1] in unp_disp)) {
							unp_disp[cols[1]] = cols[2];
						}
					}
				}
				close(ufile);

				np = 0;
				while ((getline line < pfile) > 0) {
					split(line, cols, "\t");
					if (cols[1] != "" && cols[3] != "") {
						np++;
						p_kind[np] = cols[1];
						p_slice[np] = cols[2];
						p_raw[np] = cols[3];
						p_low[np] = tolower(cols[3]);
						p_tag[np] = cols[1] ":" cols[3];
						if (cols[1] == "table") {
							p_re1[np] = kw sep p_low[np] endb;
							p_re2[np] = bt p_low[np] bt;
							p_re3[np] = "(^|[^a-z0-9_])" p_low[np] "\\.[a-z0-9_]+";
						} else {
							p_re1[np] = "(^|[^a-z0-9_])" p_low[np] endb;
						}
					}
				}
				close(pfile);

				cur = "";
				a_path = "";
				active = 0;
				n_hit_files = 0;
			}
			/^diff --git / {
				cur = "";
				a_path = "";
				active = 0;
				next;
			}
			/^--- a\// {
				a_path = substr($0, 7);
				next;
			}
			/^\+\+\+ b\// {
				cur = substr($0, 7);
				active = (cur in unp_disp) ? 1 : 0;
				next;
			}
			/^\+\+\+ \/dev\/null/ {
				cur = a_path;
				active = (cur in unp_disp) ? 1 : 0;
				next;
			}
			/^--- / || /^\+\+\+ / || /^@@/ {
				next;
			}
			/^[+-]/ {
				if (!active) next;
				body = substr($0, 2);
				low = tolower(body);
				matched_line = 0;
				for (i = 1; i <= np; i++) {
					hit = 0;
					if (p_kind[i] == "table") {
						if (low ~ p_re1[i] || low ~ p_re2[i] || low ~ p_re3[i]) hit = 1;
					} else {
						if (low ~ p_re1[i]) hit = 1;
					}
					if (hit) {
						matched_line = 1;
						key = cur SUBSEP p_tag[i];
						if (!(key in seen_tag)) {
							seen_tag[key] = 1;
							if (cur in file_tags) {
								file_tags[cur] = file_tags[cur] ", " p_tag[i];
							} else {
								file_tags[cur] = p_tag[i];
								n_hit_files++;
								hit_order[n_hit_files] = cur;
							}
						}
					}
				}
				if (matched_line) {
					sc = sample_count[cur] + 0;
					if (sc < 3) {
						sc++;
						sample_count[cur] = sc;
						trim = body;
						gsub(/^[ \t]+/, "", trim);
						if (length(trim) > 130) trim = substr(trim, 1, 127) "...";
						sample_lines[cur, sc] = substr($0, 1, 1) trim;
					}
				}
			}
			END {
				print n_hit_files > cfile;
				close(cfile);
				if (n_hit_files == 0) {
					print "  (none)";
				} else {
					for (i = 1; i <= n_hit_files; i++) {
						fpath = hit_order[i];
						printf "  %s  [%s]\n", unp_disp[fpath], file_tags[fpath];
						printf "  %s  [%s]\n", unp_disp[fpath], file_tags[fpath] > sfile;
						sc = sample_count[fpath] + 0;
						for (j = 1; j <= sc; j++) {
							printf "    %s\n", sample_lines[fpath, j] > sfile;
						}
					}
				}
				close(sfile);
			}' >"$b4_report"
		cat "$b4_report"
		if [[ -s "$work/b4_count.txt" ]]; then
			hit_count="$(cat "$work/b4_count.txt")"
		fi
	else
		echo "  (none)"
	fi
	echo ""

	# Bucket 5: Cutover merge conflict preview
	echo "[Bucket 5] Cutover Merge Conflict Preview ($local_branch vs $upstream_ref)"
	if git -C "$repo_dir" rev-parse --verify "${local_branch}^{commit}" >/dev/null 2>&1; then
		local mbase
		mbase="$(git -C "$repo_dir" merge-base "$local_branch" "$upstream_ref" 2>/dev/null || true)"
		if [[ -n "$mbase" ]]; then
			git -C "$repo_dir" diff --name-only "$mbase..$local_branch" >"$work/cutover.paths"
			if [[ -s "$work/cutover.paths" ]]; then
				local overlaps="$work/overlaps.txt"
				grep -Fxf "$work/cutover.paths" "$all_paths" | sort -u >"$overlaps" || true
				if [[ -s "$overlaps" ]]; then
					echo "  WARNING — overlapping files (conflict risk):"
					print_list_file "$overlaps" "    "
				else
					echo "  0 overlapping files (clean merge expected)"
				fi
			else
				echo "  0 local cutover commits ahead of merge-base ($local_branch)"
			fi
		else
			echo "  (no common merge-base between $local_branch and $upstream_ref)"
		fi
	else
		echo "  (local branch $local_branch not found)"
	fi
	echo ""

	local skipped_count=$((unported_total - hit_count))
	echo "Summary: $total_files changed | Skipped: $skipped_count files in unported modules (no shared/slice/table/url hits)"
	echo ""

	if (( SHOW_DIFF )); then
		echo "--- Diff Details ($name) ---"
		if [[ -s "$b2_paths" || -s "$b3_paths" ]]; then
			local -a code_args=()
			local seen_tmp="$work/code_seen.tmp"
			cat "$b2_paths" "$b3_paths" | awk 'NF && !seen[$0]++' >"$seen_tmp"
			while IFS= read -r p || [[ -n "$p" ]]; do
				[[ -n "$p" ]] && code_args+=("$p")
			done <"$seen_tmp"
			if [[ ${#code_args[@]} -gt 0 ]]; then
				echo "### Buckets 2 & 3 (Shared Core + Slices) ###"
				git -C "$repo_dir" diff -w --ignore-cr-at-eol "$watermark..$upstream_ref" -- "${code_args[@]}"
				echo ""
			fi
		fi

		if [[ -s "$b1_pairs" ]]; then
			echo "### Bucket 1 (SQL) ###"
			local sp1 sp2 line_cnt
			while IFS=$'\t' read -r sp2 sp1 || [[ -n "$sp2" ]]; do
				[[ -n "$sp2" ]] || continue
				local -a sp_args=("$sp2")
				[[ -n "${sp1:-}" ]] && sp_args+=("$sp1")
				line_cnt="$(git -C "$repo_dir" diff -w --ignore-cr-at-eol "$watermark..$upstream_ref" -- "${sp_args[@]}" | wc -l | tr -d ' ')"
				if (( line_cnt <= 80 )); then
					git -C "$repo_dir" diff -w --ignore-cr-at-eol "$watermark..$upstream_ref" -- "${sp_args[@]}"
				else
					echo "=== $sp2 ($line_cnt diff lines — showing DDL/metadata lines only) ==="
					git -C "$repo_dir" diff -w --ignore-cr-at-eol "$watermark..$upstream_ref" -- "${sp_args[@]}" | \
						grep -iE '^(diff --git|index |---|\+\+\+|@@)|create[[:space:]]+.*table|alter[[:space:]]+table|drop[[:space:]]+|daftar_referensi|hak_akses|menu' || true
				fi
				echo ""
			done <"$b1_pairs"
		fi

		if [[ -s "$b4_samples" ]]; then
			echo "### Bucket 4 (Indirect Hit Samples) ###"
			cat "$b4_samples"
			echo ""
		fi
	fi
}

matched_any=0
while IFS=$'\t' read -r r_name r_dir r_up r_wm r_loc || [[ -n "$r_name" ]]; do
	[[ -n "$r_name" ]] || continue
	if [[ -n "$FILTER_REPO" && "$r_name" != "$FILTER_REPO" ]]; then
		continue
	fi
	matched_any=1
	run_repo_triage "$r_name" "$r_dir" "$r_up" "$r_wm" "$r_loc"
done <"$REPOS_FILE"

if (( matched_any == 0 )); then
	echo "Unknown --repo '$FILTER_REPO'. Check $CONF_FILE." >&2
	exit 1
fi
