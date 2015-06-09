#!/bin/bash
# @Description: zippyshare.com file download script
#  Very loosely based on tyoyo's script at https://github.com/tyoyo/zippyshare/blob/master/zippyshare.sh
#  Entirely REWRITTEN, fixed, simplified and shortened by andreas-e (now can do everything in less than
#   90 lines; besides, original script did not work at all)
# @Usage: zippydl.sh <URL to file>

tmpdir="/tmp"
#temp file #1: information needed to build DL URL
wgettmpi="$tmpdir/.zippydldata0"
#temp file #2: dumped cookie file (from wget's --save-cookies option)
wgettmpc="$tmpdir/.zippydlcookie0"

[[ -f "$wgettmpc" || -f "$wgettmpi" ]] && rm -f "$wgettmpc" "$wgettmpi"
[[ "$1" == "" ]] && { echo -e "\nUsage: $0 <URL to file>"; exit 0; }

wget -O "$wgettmpi" "$1" --cookies=on --keep-session-cookies --save-cookies="$wgettmpc" --quiet

[[ ! -s "$wgettmpc" ]] && { echo -e "ERROR: Cookie file corrupt or missing! Aborted.\n"; exit 1; }
[[ ! -s "$wgettmpi" ]] && { echo -e "ERROR: Data file corrupt or missing! Aborted.\n"; exit 1; }

# Get cookie
 jsessionid=$(awk '/JSESSIONID/{print $7}' "$wgettmpc")

 # Get url formula; and as we're here, extract filename as well.

 dlbtnline=$(awk -F= '/'\''dlbutton'\''/{print $2}' "$wgettmpi" | sed 's/[";)(]*//g') 
 formula=$(cut -f2-4 -d+ <<<"$dlbtnline") 
 fname=$(cut -f5 -d/ <<<"$dlbtnline")

 # Get variables string into array
 read -a arr <<<$formula

 # Get variable array
 for ((i=0;i<${#arr[@]};i+=2)); do
    param[(i/2)]=${arr[i]}
 done

 for ((i=0;i<${#param[@]};i++)); do
    [[ ${param[i]} =~ [0-9]+ ]] && x=${param[i]} || \
    x=$(grep "var ${param[i]} =" "$wgettmpi" | sed 's/;$//' | cut -f2 -d=)
    [[ $x =~ [0-9]+ ]] && v[i]=$x;
 done

 ret=${v[0]}
 for ((i=0;i<${#param[@]};i+=1)); do
    ret="$ret${arr[2*i+1]}${v[i+1]}"
 done

 code=$((ret*10+3))
 referrer=$(awk -F\" '/og:url/{print $4}' "$wgettmpi")
 server=$(cut -f3 -d'/' <<<"$referrer")
 id=$(cut -f5 -d'/' <<<"$referrer")

 # cannot build download url if code is NaN
 [[ $code =~ [^0-9]+ ]] && { echo -e "\e[031m Zippyshare.com algorithm has apparently \
 changed again - please check (or request) for an update! \e[00m"; exit 1; }

# OK, all right. Build download url
  dl="http://$server/d/$id/$code/$fname"
  echo -e "\nDownloading file: $dl\n"

  # Spoof browser's user agent
  agent="Mozilla/5.0 (Windows NT 6.3; WOW64)"

  # Start downloading of file
  echo -ne "\e[033m '$fname' download starting....      \e[00m"

  wget -c -O "$fname" $dl \
  --referer='$referrer' \
  --cookies=off --header "Cookie: JSESSIONID=$jsessionid" \
  --user-agent='$agent' \
  --progress=dot \
  2>&1 | \
  grep --line-buffered "%" |
  sed -ue "s/\.//g" | 
  awk '{printf("\b\b\b\b\b\b\b[\033[ 36m%4s\033[0m ]", $2)}'

  echo -ne "\b\b\b\b\b\b\b[\e[032m Done \e[00m]"

  [[ -s "$fname" ]] && { echo -e "\e[032m Download success! \e[00m"; } || { echo -e "\e[031m Download error! \e[00m"; }

  rm -f "$wgettmpc" "$wgettmpi"
