#! /bin/bash
# @Description: zippyshare.com file download script
#  Very loosely based on tyoyo's script at https://github.com/tyoyo/zippyshare/blob/master/zippyshare.sh
#  Entirely REWRITTEN, fixed, simplified and shortened by andreas-e (now can do everything in about 30 L.o.C.
#  less than before; besides, couldn't get original script to work at all)
# @Usage: zippydl.sh <URL to file>
# Note: You may now append --debug option to the URL to check if the script still works correctly with the current
# ZippyShare site version.

ver_y="2015"
ver_mon="08"
ver_day="04"

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
of this script useless  o v e r n i g h t. YOU'VE BEEN WARNED.\n"; exit 0; }

echo -e "Retrieving data file and cookies...one second please...\n"
wget -qO "$wgettmpd" "$1" --cookies=on --keep-session-cookies --save-cookies="$wgettmpc"
[[ ! -s "$wgettmpc" ]] && { echo -e "ERROR: Cookie file corrupt or missing! Aborted.\n"; exit 1; }
[[ ! -s "$wgettmpd" ]] && { echo -e "ERROR: Data file corrupt or missing! Aborted.\n"; exit 1; }

# Get cookie
 jsessionid=$(awk '/JSESSIONID/{print $7}' "$wgettmpc")

 # Get url formula; and as we're here, extract filename as well.

 formula=$(awk -F\" '/'\''dlbutton'\''\)\.href/{print $3}' /tmp/.zippydldata0 | 
           sed -e 's/\(^+(\|)+$\)//g' -e "s/document[a-zA-Z'()\.]\+\.omg\.length/omg/")
 
 dlbtnline=$(awk -F= '/'\''dlbutton'\''\).href/{print $2}' "$wgettmpd" | sed 's/^\s*"//;s/")\?;$//') 
 
 # if dlbtnline is empty, it is highly probable that RE-CAPTCHA has been activated!! ("I am not a robot" stuff)
 # This is currently not supported (sorry)
 
 [[ "$dlbtnline" == "" ]] && 
 { echo -e "\e[0;31m\n* WARNING: Could not download file from URL '$1'!\n\n\
  It is possible that reCAPTCHA might have been activated for this file!\n\
  In this case, you will have to use your browser to download this one - sorry.\e[0;0m"; exit 0; } 

 # Get file name, and also unescape it so that the target file doesn't%20look%20like%this
 fname=$(printf `sed 's/%\(..\)/\\\\x\1/g' <<< $(echo ${dlbtnline##*/})`)

 [[ $dbgmode -eq 1 ]] && 
 echo -e "$dbg dl_line(RAW)=$dlbtnline\n$dbg formula = $formula\n$dbg filename='$fname'\n"
 
 # FIXME: Match is somewhat hackish at present! But we must make sure that variable declarations of Google Analytics 
 # et. al. are not matched as well.
 read -a vars <<< $(awk -F= '/(var [^gst]|document\.getEl.*\.omg) = "?([^n][^a][^v]|Math)/{gsub(/^[ ]+(var )?/,"",$1);print $1}' "$wgettmpd")
 IFS=";" read -a form_orig <<< $(awk '/(var [^gst]|document\.getEl.*\.omg) = "?([^n][^a][^v]|Math)/{for (i=3;i<=NF;i++) {gsub (/^=/,"",$i);printf $i}}' "$wgettmpd")

 for ((i=0;i<${#vars[@]};i++)); do
  [[ ${vars[i]} =~ \.omg$ ]] && { vars[i]="omg"; }

   tmpvar=${vars[i]}              # tmpvar = <varname> (dynamic)
   [[ $dbgmode -eq 1 ]] && echo -n "$dbg Processing variable ${vars[i]}... "

   form_orig[i]=$(sed 's/\(Math\.pow\|function(){return\)//
                       s/\(}\|()\)//g
                       s/(\([a-z]\)\s*,\s(\([a-z]\)/\1\2/
                       s/,/**/'\
                       <<< ${form_orig[i]})
   [[ ${form_orig[i]} =~ getAttribute ]] && { form_orig[i]=$(($(grep -o 'span id=\"omg\" class=\"[0-9]\"' "$wgettmpd" | cut -f4 '-d"'))); }
   declare $tmpvar=${form_orig[i]}
   form[i]=${!tmpvar}
 
   # check if formulae contain variables on their part
   # (none allowed for calculations [however arithmetic operations are!])

   [[ ${form[i]} =~ (?^[0-9]+(\s*(\+|-|\*\*?|/|%)\s*[0-9]+)*)?$ ]] &&
     { echo "bc mode"; form[i]=$(bc <<< ${form[i]}); } ||
     { [[ ${form_orig[i]} =~ \"[a-zA-Z0-9]+\" ]] && { form[i]=$((${#form_orig[i]}-2)); }\
       || { [[ ! ${form_orig[i]} =~ getAttribute ]] &&
            { form[i]=$((${form_orig[i]})); 
              [[ $dbgmode -eq 1 ]] && { echo "new form of ${vars[i]}= $((${form[i]}))";};
            }
          }
     } 
     # redeclare (assigning altered value of formula)
     declare $tmpvar=${form[i]}
 
     [[ $dbgmode -eq 1 ]] && echo "${vars[i]} set to ${form[i]}"
  done

 # Get variables string into array
 read -a arr <<<$formula

 # Get variable array
 for ((i=0;i<${#arr[@]};i+=2)); do
   [[ $dbgmode -eq 1 ]] && echo "$dbg Assigning arr #$i w/value '${arr[i]}' to parameter"
    
   param[(i/2)]=$(sed 's/()$//' <<< ${arr[i]})
   [[ $dbgmode -eq 1 && ${arr[i]} =~ [a-z]() ]] && echo "$dbg Parameter transformed to ${param[(i/2)]}"
 done

for ((i=0;i<${#param[@]};i++)); do
    [[ $dbgmode -eq 1 ]] && echo "[DEBUG] Processing param[$i] = ${param[i]}"  

    [[ ${param[i]} == "omg" ]] && { x=${form[i/2]}; } ||
       { [[ ${param[i]} =~ [0-9]+ ]] && x=${param[i]} ||
         { x=$(grep "var ${param[i]} = \([^n][^a][^v]\|Math\)" "$wgettmpd" | sed 's/;$//' | cut -f2 -d=); 
           [[ $x =~ Math\. || $x =~ func ]] && 
            {  x=$(($(sed 's/\(Math\.pow\|function() {return\)//
                           s/\(}\|()\)//g
                           s/(\([a-z]\)\s*,\s(\([a-z]\)/\1\2/
                           s/,/**/'\
               <<< "$x"))); }
           [[ $x =~ getAttribute ]] && { v[i]=$(($(grep -o 'span id=\"omg\" class=\"[0-9]\"' "$wgettmpd" | cut -f4 '-d"'))); }
         }
       }
    [[ $dbgmode -eq 1 ]] && echo "$dbg Calculating result of F : '$x'"
    [[ $x =~ [0-9]+ ]] && v[i]=$x;
 done

 # === DIRTY HACK (TEMP) ====
 [[ ${v[0]} =~ [0-9]+ ]] && 
  { ret=$((${v[0]})); 
  } || { echo -e "\n** INTERNAL ERROR! (v is not a number - calculation not possible)\n"; exit 1; }
 # ==========================

 for ((i=0;i<${#param[@]};i+=1)); do
    ret="$ret${arr[2*i+1]}${v[i+1]}"
 done

 code=$((ret))
 [[ $dbgmode -eq 1 ]] && echo "$dbg Final code (F): $code"
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
