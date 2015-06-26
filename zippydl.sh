#!/bin/bash
# @Description: zippyshare.com file download script
#  Very loosely based on tyoyo's script at https://github.com/tyoyo/zippyshare/blob/master/zippyshare.sh
#  Entirely REWRITTEN, fixed, simplified and shortened by andreas-e (now can do everything in about 30 L.o.C.
#  less than before; besides, couldn't get original script to work at all)
# @Usage: zippydl.sh <URL to file>
# Note: You may now append --debug option to the URL to check if the script still works correctly with the current
# ZippyShare site version.

ver_y="2015"
ver_mon="06"
ver_day="27"

dbg="[DEBUG]"
[[ "$2" == "--debug" ]] && dbgmode=1 || dbgmode=0

tmpdir="/tmp"
#temp file #1: dumped cookie file (from wget's --save-cookies option)
wgettmpc="$tmpdir/.zippydlcookie0"
#temp file #2: information (data) needed to build DL URL
wgettmpd="$tmpdir/.zippydldata0"

[[ -f "$wgettmpc" || -f "$wgettmpd" ]] && rm -f "$wgettmpc" "$wgettmpd"
[[ "$1" == "" ]] && { echo -e "\nzippyDL version $ver_y-$ver_mon-$ver_day\n\n\
Usage: $0 <URL to file>\n\n**Note**: Algorithms may change DAILY and can render the current version\n\
of this script useless overnight. YOU'VE BEEN WARNED."; exit 0; }

wget -qO "$wgettmpd" "$1" --cookies=on --keep-session-cookies --save-cookies="$wgettmpc"

[[ ! -s "$wgettmpc" ]] && { echo -e "ERROR: Cookie file corrupt or missing! Aborted.\n"; exit 1; }
[[ ! -s "$wgettmpd" ]] && { echo -e "ERROR: Data file corrupt or missing! Aborted.\n"; exit 1; }

# Get cookie
 jsessionid=$(awk '/JSESSIONID/{print $7}' "$wgettmpc")

 # Get url formula; and as we're here, extract filename as well.

 dlbtnline=$(awk -F, '/'\''dlbutton'\''/{print $2}' "$wgettmpd" | sed 's/^\s*[";)(]*//g') 
 
 # if dlbtnline is empty, it is highly probable that RE-CAPTCHA has been activated!! ("I am not a robot" stuff)
 # This is currently not supported (sorry)
 
 [[ "$dlbtnline" == "" ]] && 
 { echo -e "\e[0;31m\n* WARNING: Could not download file from URL '$1'!\n\n\
  zippyDL has detected that reCAPTCHA has been activated for this file!\n\
  You must use your browser to download this one - sorry.\e[0;0m"; exit 0; } 

 formula=$(cut -f4 -d\/ <<<"$dlbtnline" | sed 's/\(^"+\|+"$\)//g')
 # Get file name, and also unescape it so that the target file doesn't%20look%20like%this
 fname=$(cut -f5 -d/ <<<"$dlbtnline" | sed 's/");$//' | awk -niord '{printf RT?$0chr("0x"substr(RT,2)):$0}' RS=%..)

 [[ $dbgmode -eq 1 ]] && 
 echo -e "$dbg dl_line(RAW)=$dlbtnline\n$dbg formula = $formula\nfilename=$fname\n"
 
 # FIXME: Match is totally hackish at present! But we must make sure that variable declarations of Google Analytics 
 # et. al. are not matched as well.
 read -a vars <<< $(awk '/var [^ast] =/{print $2}' "$wgettmpd")
 IFS=";" read -a form_orig <<< $(awk '/var [^ast] = /{for (i=4;i<=NF;i++) printf $i;next}' "$wgettmpd")
  
 for ((i=0;i<${#vars[@]};i++)); do
   tmpvar=${vars[i]}              # tmpvar = <varname> (dynamic)
   declare $tmpvar=${form_orig[i]}
   form[i]=${!tmpvar}
 
   # check formulae for variable names (none allowed for calculations [but arithmetic operations are!])

   [[ ${form[i]} =~ ^[0-9]+(\s*(\+|-|\*|/||%)\s*[0-9]+)*$ ]] &&
     { form[i]=$(bc <<< ${form[i]}); } ||
     { [[ $dbgmode -eq 1 ]] && echo "new form of ${vars[i]}= $((${form[i]}))"; }
 
     # redeclare (assigning altered value of formula)
     declare $tmpvar=${form[i]}
 
     [[ $dbgmode -eq 1 ]] && echo "$dbg ${vars[i]} has value of ${form[i]}"
  done

 # Get variables string into array
 read -a arr <<<$formula

 # Get variable array
 for ((i=0;i<${#arr[@]};i+=2)); do
    param[(i/2)]=${arr[i]}
 done

 for ((i=0;i<${#param[@]};i++)); do
    [[ ${param[i]} =~ [0-9]+ ]] && x=${param[i]} || \
    x=$(grep "var ${param[i]} =" "$wgettmpd" | sed 's/;$//' | cut -f2 -d=)
    [[ "$2" == "--debug" ]] && echo "$dbg x = $x"
    [[ $x =~ [0-9]+ ]] && v[i]=$x;
 done

 ret=${v[0]}
 for ((i=0;i<${#param[@]};i+=1)); do
    ret="$ret${arr[2*i+1]}${v[i+1]}"
 done

 code=$((ret))
 referrer=$(awk -F\" '/og:url/{print $4}' "$wgettmpd")
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

  wget -cU '$agent' -O "$fname" $dl \
  --referer='$referrer' \
  --cookies=off --header "Cookie: JSESSIONID=$jsessionid" \
  --progress=dot \
  --restrict-file-names=unix,nocontrol \
  2>&1 | \
  grep --line-buffered "%" |
  sed -ue "s/\.//g" | 
  awk '{printf("\b\b\b\b\b\b\b[\033[ 36m%4s\033[0m ]", $2)}'

  echo -ne "\b\b\b\b\b\b\b[\e[032m Done \e[00m]"

  [[ -s "$fname" ]] && { echo -e "\e[032m Download success! \e[00m"; } || { echo -e "\e[031m Download error! \e[00m"; }

  rm -f "$wgettmpc" "$wgettmpd"
