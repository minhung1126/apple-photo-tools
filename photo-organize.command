#!/bin/zsh

# Apple Photo Tools for macOS
# 把本檔案複製到要整理的照片根目錄，雙擊執行。
# 根目錄散圖 -> YYYYMM00；既有 YYYYMMDD / YYYYMMDD 主題 資料夾原地整理。

ROOT="${0:A:h}"
cd "$ROOT" || exit 1

EXIFTOOL="$(command -v exiftool 2>/dev/null || true)"
TMP_BASE="${TMPDIR:-/tmp/}"
WORK_DIR="$(mktemp -d "${TMP_BASE%/}/apple-photo-tools.XXXXXX")" || exit 1
ROOT_PLAN="$WORK_DIR/root.tsv"
EDIT_PLAN="$WORK_DIR/edit.tsv"
RENAME_PLAN="$WORK_DIR/rename.tsv"

: > "$ROOT_PLAN"
: > "$EDIT_PLAN"
: > "$RENAME_PLAN"

cleanup() {
  /bin/rm -rf "$WORK_DIR" 2>/dev/null
}
trap cleanup EXIT

title() {
  print ""
  print "========================================================================"
  print "$1"
  print "========================================================================"
}

pause_end() {
  print ""
  print "完成。按 Enter 關閉視窗。"
  read -r _
}

confirm_yes() {
  print ""
  print "$1"
  print -n "輸入 YES 才會執行："
  local answer
  read -r answer
  [[ "$answer" == "YES" ]]
}

lower_ext() {
  local name="${1:t}"
  local ext="${name##*.}"
  print -r -- "${ext:l}"
}

is_media() {
  local ext="$(lower_ext "$1")"
  case "$ext" in
    jpg|jpeg|heic|heif|png|dng|tif|tiff|gif|webp|mov|mp4|m4v) return 0 ;;
    *) return 1 ;;
  esac
}

is_image() {
  local ext="$(lower_ext "$1")"
  case "$ext" in
    jpg|jpeg|heic|heif|png|dng|tif|tiff|gif|webp) return 0 ;;
    *) return 1 ;;
  esac
}

is_aae() {
  [[ "$(lower_ext "$1")" == "aae" ]]
}

is_capture_stamp() {
  local value="$1"
  local parsed=""
  [[ "$value" == [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9] ]] || return 1
  parsed="$(/bin/date -j -f "%Y%m%d-%H%M%S" "$value" "+%Y%m%d-%H%M%S" 2>/dev/null)" || return 1
  [[ "$parsed" == "$value" ]]
}

capture_stamp() {
  local file="$1"
  local stamp=""

  # 如果使用者有安裝 exiftool，優先使用真正的媒體拍攝時間。
  if [[ -n "$EXIFTOOL" ]]; then
    stamp="$("$EXIFTOOL" -s3 -d "%Y%m%d-%H%M%S"       -DateTimeOriginal -CreateDate -MediaCreateDate -TrackCreateDate       "$file" 2>/dev/null | /usr/bin/grep -E '^[0-9]{8}-[0-9]{6}$' | /usr/bin/head -n 1)"
    if is_capture_stamp "$stamp"; then
      print -r -- "$stamp"
      return 0
    fi
  fi

  # 不使用 Spotlight / filesystem creation / birth / modification time 當作拍攝時間。
  # kMDItemContentCreationDate 對沒有內嵌拍攝資訊的檔案也可能退回檔案時間，
  # 因此只有 ExifTool 直接讀到媒體內部時間才視為可靠。
  return 1
}

capture_stamp_from_files() {
  local file stamp
  for file in "$@"; do
    [[ -e "$file" ]] || continue
    stamp="$(capture_stamp "$file")" || continue
    if is_capture_stamp "$stamp"; then
      print -r -- "$stamp"
      return 0
    fi
  done
  return 1
}

filename_stamp() {
  local file="$1"
  local name="${file:t}"
  local prefix=""

  [[ "$name" == [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]_* ]] || return 1
  prefix="${name[1,15]}"
  is_capture_stamp "$prefix" || return 1
  print -r -- "$prefix"
}

filename_stamp_from_files() {
  local file stamp
  for file in "$@"; do
    [[ -e "$file" ]] || continue
    stamp="$(filename_stamp "$file")" || continue
    print -r -- "$stamp"
    return 0
  done
  return 1
}

filesystem_birth_stamp() {
  local file="$1"
  local epoch stamp
  epoch="$(/usr/bin/stat -f "%B" "$file" 2>/dev/null)" || return 1
  [[ -n "$epoch" && "$epoch" != "-1" ]] || return 1
  stamp="$(/bin/date -r "$epoch" "+%Y%m%d-%H%M%S" 2>/dev/null)" || return 1
  is_capture_stamp "$stamp" || return 1
  print -r -- "$stamp"
}

filesystem_birth_stamp_from_files() {
  local file stamp
  for file in "$@"; do
    [[ -e "$file" ]] || continue
    is_media "$file" || continue
    stamp="$(filesystem_birth_stamp "$file")" || continue
    print -r -- "$stamp"
    return 0
  done
  return 1
}

filesystem_mtime_stamp() {
  local file="$1"
  local epoch stamp
  epoch="$(/usr/bin/stat -f "%m" "$file" 2>/dev/null)" || return 1
  [[ -n "$epoch" ]] || return 1
  stamp="$(/bin/date -r "$epoch" "+%Y%m%d-%H%M%S" 2>/dev/null)" || return 1
  is_capture_stamp "$stamp" || return 1
  print -r -- "$stamp"
}

filesystem_mtime_stamp_from_files() {
  local file stamp
  for file in "$@"; do
    [[ -e "$file" ]] || continue
    is_media "$file" || continue
    stamp="$(filesystem_mtime_stamp "$file")" || continue
    print -r -- "$stamp"
    return 0
  done
  return 1
}

# 日常一律使用同一套時間規則，不判斷檔案來源。
# 回傳格式：source:YYYYMMDD-HHMMSS
daily_stamp_info_from_files() {
  local stamp=""

  stamp="$(filename_stamp_from_files "$@")" || stamp=""
  if [[ -n "$stamp" ]]; then
    print -r -- "filename:$stamp"
    return 0
  fi

  stamp="$(capture_stamp_from_files "$@")" || stamp=""
  if [[ -n "$stamp" ]]; then
    print -r -- "metadata:$stamp"
    return 0
  fi

  stamp="$(filesystem_birth_stamp_from_files "$@")" || stamp=""
  if [[ -n "$stamp" ]]; then
    print -r -- "birth:$stamp"
    return 0
  fi

  stamp="$(filesystem_mtime_stamp_from_files "$@")" || stamp=""
  if [[ -n "$stamp" ]]; then
    print -r -- "mtime:$stamp"
    return 0
  fi

  return 1
}

warn_timestamp_fallback() {
  local source="$1"
  local file="$2"
  case "$source" in
    birth)
      print "[WARN] 找不到內嵌拍攝時間，使用檔案建立時間：$(relative_path "$file")"
      ;;
    mtime)
      print "[WARN] 找不到內嵌拍攝時間與建立時間，最後使用檔案修改時間：$(relative_path "$file")"
      ;;
  esac
}

append_plan() {
  local plan="$1"
  local group="$2"
  local src="$3"
  local dst="$4"
  print -r -- "$group"$'\t'"$src"$'\t'"$dst" >> "$plan"
}

relative_path() {
  local p="$1"
  if [[ "$p" == "$ROOT"/* ]]; then
    print -r -- "${p#$ROOT/}"
  else
    print -r -- "$p"
  fi
}

plan_count() {
  local plan="$1"
  /usr/bin/wc -l < "$plan" | /usr/bin/tr -d ' '
}

preview_plan() {
  local plan="$1"
  local label="$2"

  if [[ ! -s "$plan" ]]; then
    print ""
    print "[$label] 沒有需要處理的項目。"
    return 1
  fi

  print ""
  print "[$label] 預覽："
  local group src dst
  while IFS=$'\t' read -r group src dst; do
    print "  $(relative_path "$src")"
    print "    -> $(relative_path "$dst")"
  done < "$plan"

  print ""
  print "共 $(plan_count "$plan") 個檔案動作。"
  return 0
}

nearest_existing_dir() {
  local p="$1"
  while [[ ! -d "$p" && "$p" != "/" ]]; do
    p="${p:h}"
  done
  print -r -- "$p"
}

same_device() {
  local src="$1"
  local dst="$2"
  local dst_anchor="$(nearest_existing_dir "${dst:h}")"
  local src_dev="$(/usr/bin/stat -f "%d" "$src" 2>/dev/null)"
  local dst_dev="$(/usr/bin/stat -f "%d" "$dst_anchor" 2>/dev/null)"
  [[ -n "$src_dev" && "$src_dev" == "$dst_dev" ]]
}

# 依 group 執行。若同一組任一目的地衝突或跨磁碟，整組跳過。
# 若同組中途失敗，已完成的項目會盡量回滾。
execute_grouped_plan() {
  local plan="$1"
  local label="$2"
  typeset -A visited

  local group src dst
  local ok_groups=0
  local skipped_groups=0
  local failed_groups=0

  while IFS=$'\t' read -r group src dst; do
    [[ -n "$group" ]] || continue
    [[ -n "${visited[$group]-}" ]] && continue
    visited[$group]=1

    local -a sources
    local -a destinations
    local g2 s2 d2
    sources=()
    destinations=()

    while IFS=$'\t' read -r g2 s2 d2; do
      if [[ "$g2" == "$group" ]]; then
        sources+=("$s2")
        destinations+=("$d2")
      fi
    done < "$plan"

    local blocked=0
    local i existing_is_source s d dest_key
    typeset -A planned_destinations
    planned_destinations=()

    for (( i=1; i<=${#sources[@]}; i++ )); do
      s="${sources[$i]}"
      d="${destinations[$i]}"

      if [[ ! -e "$s" ]]; then
        print "[SKIP][$label] 來源已不存在：$(relative_path "$s")"
        blocked=1
        break
      fi

      # 對大小寫不敏感檔案系統也保守處理，同組目的檔重複就整組跳過。
      dest_key="${d:l}"
      if [[ -n "${planned_destinations[$dest_key]-}" ]]; then
        print "[SKIP][$label] 同組內目的檔名碰撞：$(relative_path "$d")"
        blocked=1
        break
      fi
      planned_destinations[$dest_key]=1

      if ! same_device "$s" "$d"; then
        print "[SKIP][$label] 偵測到跨磁碟：$(relative_path "$s")"
        blocked=1
        break
      fi

      if [[ -e "$d" ]]; then
        existing_is_source=0
        local candidate
        for candidate in "${sources[@]}"; do
          if [[ "$candidate" == "$d" ]]; then
            existing_is_source=1
            break
          fi
        done

        if (( existing_is_source == 0 )); then
          print "[SKIP][$label] 目的檔已存在：$(relative_path "$d")"
          blocked=1
          break
        fi
      fi
    done

    if (( blocked != 0 )); then
      (( skipped_groups++ ))
      continue
    fi

    local -a completed_src
    local -a completed_dst
    completed_src=()
    completed_dst=()
    local group_failed=0

    for (( i=1; i<=${#sources[@]}; i++ )); do
      s="${sources[$i]}"
      d="${destinations[$i]}"

      /bin/mkdir -p "${d:h}" || {
        group_failed=1
        break
      }

      # 目的地若是本組稍早的 source，理論上此時已經被搬走。
      if [[ -e "$d" ]]; then
        print "[ERROR][$label] 執行時目的檔仍存在：$(relative_path "$d")"
        group_failed=1
        break
      fi

      if /bin/mv -n "$s" "$d" && [[ ! -e "$s" && -e "$d" ]]; then
        completed_src+=("$s")
        completed_dst+=("$d")
      else
        print "[ERROR][$label] 無法安全移動或目的檔突然出現：$(relative_path "$s")"
        group_failed=1
        break
      fi
    done

    if (( group_failed != 0 )); then
      for (( i=${#completed_src[@]}; i>=1; i-- )); do
        s="${completed_src[$i]}"
        d="${completed_dst[$i]}"
        if [[ -e "$d" && ! -e "$s" ]]; then
          /bin/mkdir -p "${s:h}" 2>/dev/null
          if ! /bin/mv -n "$d" "$s" 2>/dev/null || [[ -e "$d" || ! -e "$s" ]]; then
            print "[ROLLBACK ERROR] $(relative_path "$d")"
          fi
        fi
      done
      (( failed_groups++ ))
    else
      (( ok_groups++ ))
    fi
  done < "$plan"

  print ""
  print "[$label] 完成：成功群組 $ok_groups，跳過 $skipped_groups，失敗 $failed_groups。"
}

archive_dirs() {
  local dir name
  for dir in "$ROOT"/*(/N); do
    name="${dir:t}"
    case "$name" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
        print -r -- "$dir"
        ;;
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\ *)
        print -r -- "$dir"
        ;;
    esac
  done
}

is_daily_dir() {
  local name="${1:t}"
  [[ "$name" == [0-9][0-9][0-9][0-9][0-9][0-9]00 ]]
}

build_root_plan() {
  local plan="$1"
  typeset -A seen
  local counter=0

  local file name stem family num stamp month dest_dir group
  local -a candidates
  local primary c

  for file in "$ROOT"/*(.N); do
    is_media "$file" || continue

    name="${file:t}"
    stem="${name%.*}"
    family="$stem"

    if [[ "$stem" == IMG_E[0-9][0-9][0-9][0-9] ]]; then
      num="${stem#IMG_E}"
      family="APPLE:$num"
    elif [[ "$stem" == IMG_[0-9][0-9][0-9][0-9] ]]; then
      num="${stem#IMG_}"
      family="APPLE:$num"
    fi

    [[ -n "${seen[$family]-}" ]] && continue
    seen[$family]=1
    (( counter++ ))
    group="ROOT:$counter"

    candidates=()

    if [[ "$family" == APPLE:* ]]; then
      num="${family#APPLE:}"
      candidates+=("$ROOT"/IMG_"$num".*(.N))
      candidates+=("$ROOT"/IMG_E"$num".*(.N))
    else
      candidates+=("$ROOT"/"$stem".*(.N))
    fi

    primary=""
    for c in "${candidates[@]}"; do
      if is_image "$c"; then
        primary="$c"
        break
      fi
    done
    if [[ -z "$primary" ]]; then
      for c in "${candidates[@]}"; do
        if is_media "$c"; then
          primary="$c"
          break
        fi
      done
    fi
    [[ -n "$primary" ]] || continue

    local stamp_info stamp_source
    stamp_info="$(daily_stamp_info_from_files "${candidates[@]}")" || {
      print "[WARN] 無法取得任何可用時間，保持原位：$(relative_path "$primary")"
      continue
    }
    stamp_source="${stamp_info%%:*}"
    stamp="${stamp_info#*:}"
    warn_timestamp_fallback "$stamp_source" "$primary"
    month="${stamp[1,6]}"
    dest_dir="$ROOT/${month}00"

    for c in "${candidates[@]}"; do
      if is_media "$c" || is_aae "$c"; then
        append_plan "$plan" "$group" "$c" "$dest_dir/${c:t}"
      fi
    done
  done
}

build_edit_plan() {
  local plan="$1"
  typeset -A seen
  local counter=0
  local meta_counter=0
  local dir file stem num key group c ext target

  local -a dirs
  dirs=("${(@f)$(archive_dirs)}")

  for dir in "${dirs[@]}"; do
    for file in "$dir"/IMG_E[0-9][0-9][0-9][0-9].*(.N); do
      is_media "$file" || continue

      stem="${file:t}"
      stem="${stem%.*}"
      if [[ "$stem" == IMG_E[0-9][0-9][0-9][0-9] ]]; then
        num="${stem#IMG_E}"
      else
        continue
      fi

      key="$dir|$num"
      [[ -n "${seen[$key]-}" ]] && continue
      seen[$key]=1
      (( counter++ ))
      group="EDIT:$counter"

      # 先把同編號原始媒體全部歸檔。
      for c in "$dir"/IMG_"$num".*(.N); do
        is_media "$c" || continue
        append_plan "$plan" "$group" "$c" "$dir/Originals/${c:t}"
      done

      # 再把 IMG_E#### 升成主檔 IMG_####，保留編輯版副檔名。
      for c in "$dir"/IMG_E"$num".*(.N); do
        is_media "$c" || continue
        ext="${c:t}"
        ext="${ext##*.}"
        target="$dir/IMG_$num.$ext"
        append_plan "$plan" "$group" "$c" "$target"
      done
    done

    # AAE 一律歸檔，不刪除。
    for file in "$dir"/*(.N); do
      is_aae "$file" || continue
      (( meta_counter++ ))
      group="AAE:$meta_counter"
      append_plan "$plan" "$group" "$file" "$dir/Originals/AAE/${file:t}"
    done
  done
}

build_rename_plan() {
  local plan="$1"
  typeset -A seen
  local counter=0
  local dir file name stem key group primary stamp c ext dest num
  local -a dirs candidates original_candidates pending_edits

  dirs=("${(@f)$(archive_dirs)}")

  for dir in "${dirs[@]}"; do
    local daily=0
    is_daily_dir "$dir" && daily=1

    # 主題資料夾完全不做一般檔名重新命名。
    # 其中的 IMG_E#### -> IMG_#### 只由 Stage 2 的編輯照片整理負責。
    (( daily == 1 )) || continue

    for file in "$dir"/*(.N); do
      is_media "$file" || continue

      name="${file:t}"
      stem="${name%.*}"

      # 已經符合日常時間前綴格式的檔案永遠不重複處理。
      [[ "$stem" == [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]_* ]] && continue

      # 日常 YYYYMM00：所有主媒體都要加拍攝時間。
      # 若 IMG_E#### 還存在，代表編輯版整理未執行/失敗，整組先不要改名，
      # 避免把原檔與待處理編輯版拆散。
      [[ "$stem" == IMG_E[0-9][0-9][0-9][0-9] ]] && continue

      if [[ "$stem" == IMG_[0-9][0-9][0-9][0-9] ]]; then
        num="${stem#IMG_}"
        pending_edits=("$dir"/IMG_E"$num".*(.N))
        if (( ${#pending_edits[@]} > 0 )); then
          continue
        fi
      fi

      key="$dir|$stem"
      [[ -n "${seen[$key]-}" ]] && continue
      seen[$key]=1
      (( counter++ ))
      group="RENAME:$counter"

      candidates=("$dir"/"$stem".*(.N))
      primary="$file"
      stamp=""

      local stamp_info stamp_source
      stamp_info=""

      # 編輯後主檔優先沿用 Originals 同 basename 原始媒體的時間。
      if [[ "$stem" == IMG_[0-9][0-9][0-9][0-9] ]]; then
        original_candidates=("$dir"/Originals/"$stem".*(.N))
        stamp_info="$(daily_stamp_info_from_files "${original_candidates[@]}")" || stamp_info=""
      fi

      if [[ -z "$stamp_info" ]]; then
        stamp_info="$(daily_stamp_info_from_files "${candidates[@]}")" || stamp_info=""
      fi

      if [[ -z "$stamp_info" ]]; then
        print "[WARN] 無法取得任何可用時間，無法重新命名：$(relative_path "$file")"
        continue
      fi

      stamp_source="${stamp_info%%:*}"
      stamp="${stamp_info#*:}"
      warn_timestamp_fallback "$stamp_source" "$file"

      for c in "${candidates[@]}"; do
        is_media "$c" || continue
        ext="${c:t}"
        ext="${ext##*.}"
        dest="$dir/${stamp}_${stem}.$ext"
        append_plan "$plan" "$group" "$c" "$dest"
      done
    done
  done
}

run_stage() {
  local plan="$1"
  local label="$2"
  local question="$3"

  if preview_plan "$plan" "$label"; then
    if confirm_yes "$question"; then
      execute_grouped_plan "$plan" "$label"
    else
      print "[$label] 已取消，沒有變更檔案。"
    fi
  fi
}

title "Apple Photo Tools — macOS 歸檔"
print "工作資料夾：$ROOT"
print ""
if [[ -z "$EXIFTOOL" ]]; then
  print "[WARN] 未安裝 ExifTool：日常仍會整理，但只能從檔案建立/修改時間取得日期。"
  print "       建議安裝：brew install exiftool"
  print ""
fi
print "規則："
print "  1. 根目錄散著的照片/影片依拍攝月份移到 YYYYMM00，例如 20260900。"
print "  2. 你自己建立的主題資料夾，例如「20260910 QWER」，不會被改名或搬走。"
print "  3. 日常 YYYYMM00：所有主媒體一律整理成 YYYYMMDD-HHMMSS_原始檔名.ext。"
print "  4. 主題 YYYYMMDD 主題：一般媒體全部保留原檔名，不做 metadata 重新命名。"
print "  5. 有 IMG_E#### 編輯版時：編輯版成為主檔；原始媒體進 Originals/。"
print "  6. AAE 不刪除，放到 Originals/AAE/。"
print "  7. 日常時間來源統一：既有前綴 → 內嵌 metadata → 建立時間 → 修改時間。"
print "  8. 不判斷相機/截圖/下載來源；日常一律套用同一套命名規則。"
print "  9. 不覆寫既有檔案；同組遇到衝突會整組跳過；跨磁碟會跳過。"

# 第一階段：根目錄散圖按月份進「日常」資料夾。
build_root_plan "$ROOT_PLAN"
run_stage "$ROOT_PLAN" "散圖按月份整理" "以上散圖將移到對應的 YYYYMM00。"

# 第二階段：處理日常與主題資料夾內的 Apple 編輯版 / 原檔 / AAE。
build_edit_plan "$EDIT_PLAN"
run_stage "$EDIT_PLAN" "編輯版與原檔整理" "以上編輯版將留作主檔，原始檔與 AAE 將歸檔到 Originals。"

# 第三階段：只有日常 YYYYMM00 做 metadata 命名；主題資料夾不做一般重新命名。
build_rename_plan "$RENAME_PLAN"
run_stage "$RENAME_PLAN" "日常 Metadata 檔名整理" "以上日常檔案將依拍攝時間重新命名；主題資料夾不會在此階段改名。"

print ""
print "最後的典型結構："
print "  20260900/"
print "    20260921-184501_IMG_1234.JPG"
print "    20260921-190012_IMG_5678.HEIC"
print "    20260921-190012_IMG_5678.MOV"
print "    Originals/"
print "      IMG_1234.HEIC"
print "      AAE/"
print "  20260910 QWER/"
print "    IMG_5678.JPG"
print "    IMG_5679.HEIC"
print "    Originals/"

pause_end
