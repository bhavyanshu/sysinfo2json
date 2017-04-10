#!/bin/bash
#title: sysinfo2json.sh
#description: Script to generate system information from /proc/cpuinfo, dmidecode, lshw in json format.
#author: Bhavyanshu Parasher (https://bhavyanshu.me)
#usage: sudo bash sysinfo2json.sh
#==============================================================================

getCPUInfo() {
  cpufile="/proc/cpuinfo"
  start='"Processors" : ['
  end=']'
  if [ -f "$cpufile" ]; then
    count=$(grep -Ec 'processor' $cpufile)
    i=1
    while [ $i -le $count ]; do
      fetch="$(cat "$cpufile" | awk -vi="$i" '/processor/{j++}j==i')"
      grep_processor=$(echo "$fetch" | perl -F: -alpe 's/.*:*/"$F[0]":"$F[1]"/' | tr -s '\n' ','  |  sed 's/\s\(":"\)\s/":"/g' | sed -zE 's/[[:space:]]+([:"])/\1/g' )
      proc="{"${grep_processor::-1}"},"
      mid=$mid$proc
      i=$((i+1))
    done
  fi
  echo $start${mid::-1}$end
}

getMemInfo() {
  start='"MemoryUnits" : ['
  end=']'
  memInfo=$(dmidecode --type memory | grep 'Memory\|Size\|Type\|Speed\|Manufacturer\|Serial\|Part' | sed "/Memory/d")
  count=$(echo "$memInfo" | grep -Ec 'Size')
  i=1
  while [ $i -le $count ]; do
    fetch="$(echo "$memInfo" | awk -vi="$i" '/Size/{j++}j==i')"
    grep_processor=$(echo "$fetch" | perl -F: -alpe 's/.*:*/"$F[0]":"$F[1]"/' | tr -s '\n' ','  |  sed 's/\s\(":"\)\s/":"/g' | sed -zE 's/[[:space:]]+([:"a-zA-Z0-9])/\1/g' )
    proc="{"${grep_processor::-1}"},"
    mid=$mid$proc
    i=$((i+1))
  done
  echo $start${mid::-1}$end
}

getDiskInfo() {
  start='"Disks" : ['
  end=']'
  diskInfo=$(sudo lshw -quiet -class disk | sed "/*-/d")
  count=$(lshw -quiet -class disk | grep -Ec '*-disk')
  i=1
  while [ $i -le $count ]; do
    fetch="$(echo "$diskInfo" | awk -vi="$i" '/description/{j++}j==i')"
    grep_processor=$(echo "$fetch" | perl -F: -alpe 's/.*:*/"$F[0]":"$F[1]"/' | tr -s '\n' ','  |  sed 's/\s\(":"\)\s/":"/g' | sed -zE 's/[[:space:]]+([:"a-zA-Z0-9])/\1/g' )
    proc="{"${grep_processor::-1}"},"
    mid=$mid$proc
    i=$((i+1))
  done
  echo $start${mid::-1}$end
}

getMotherboardInfo() {
  start='"Motherboard" : {'
  end='}'
  mbinfo=$(dmidecode --type baseboard | grep 'Manufacturer\|Name\|Version\|Serial')
  grep_processor=$(echo "$mbinfo" | perl -F: -alpe 's/.*:*/"$F[0]":"$F[1]"/' | tr -s '\n' ','  |  sed 's/\s\(":"\)\s/":"/g' | sed -zE 's/[[:space:]]+([:"a-zA-Z0-9])/\1/g' )
  proc=${grep_processor::-1}
  local mid=$mid$proc
  echo $start${mid}$end
}

outputFile() {
  boardvendor=$(dmidecode -s baseboard-manufacturer)
  boardserial=$(dmidecode -s baseboard-serial-number)
  echo "$boardvendor-$boardserial.json"
}

getLogDetails() {
  echo '"LoggedOn" : "'$(date "+%Y-%m-%d %H:%M:%S")'"'
}

main() {
  if [[ $EUID -ne 0 ]]; then
     echo "Run this script using sudo/root" 1>&2
     exit 1
  fi

  logdetails=$(getLogDetails)

  echo "|>>>>>>>> Generating Motherboard Info..."
  motherboard=$(getMotherboardInfo)

  echo "|>>>>>>>> Generating Processor Info..."
  cpu=$(getCPUInfo)

  echo "|>>>>>>>> Generating Memory Unit Info..."
  mem=$(getMemInfo)

  echo "|>>>>>>>> Generating Disk Info..."
  disk=$(getDiskInfo)

  echo "|>>>>>>>> Compiling..."
  filename=$(outputFile)
  echo "{$logdetails,$motherboard,$cpu,$mem,$disk}" > $filename

  echo "|>>>>>>>> Done, Generated file -> $filename |"
}

main
