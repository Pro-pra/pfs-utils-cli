#!/bin/sh
#Install .pfs (for PuppyRus), by Zay, GPL v3.
#VERSION 3.0
. /usr/bin/pfsfunc
allow_only_root

mkdir -p $PFSDIR 2>/dev/null

if [ "$1" ]; then
  instfile="$1"
else
  echo "Usage: $(basename "$0") FILE"; exit 1
fi
if [ ! -f "${instfile}" ]; then
  echo "File \"${instfile}\" not found!" >&2; exit 1
fi
status=0

bsname="$(basename "${instfile}")"
if [ -d "/tmp/.pfs/install/${bsname}" ]; then
  rmdir "/tmp/.pfs/install/${bsname}" 2>/dev/null
  if [ -d "/tmp/.pfs/install/${bsname}" ]; then
    echo "Progress is already running!" >&2; exit 1
  fi
fi
mkdir -p "/tmp/.pfs/install/${bsname}"

listpackage=""
for arg in "$@"
do
  case "${arg}" in 
    "-p" | "--packages" | "-up" | "-pu") upacklist="yes";;
    "-lp" | "-pl") upacklist="yes"; insmode="lower";;
    "-l" | "--lower") insmode="lower";;
    "-u" | "--upper") ;;
    "-"*[A-Za-z]*) echo "$(basename "$0"): invalid option -- '$(echo ${arg} | tr -d '-')'" >&2; exit 1;;
    *) [ "${upacklist}" = "yes" ] && listpackage="${listpackage}${arg}$IFS";;
  esac
done
[ "${listpackage}" = "" ] && listpackage="$(unsquashfs -l "${instfile}" | grep "${PFSDIR}/mount/" | cut -f5 -d'/' | sort -uf)"
allfiles="`echo "${listpackage}" | while read pack; do
  unsquashfs -l "${instfile}" 2>/dev/null | grep -q "${PFSDIR}/mount/${pack}/pfs.files"
  [ $? -gt 0 ] && continue
  unsquashfs -d "/tmp/.pfs/install/${bsname}/${pack}" "${instfile}" -ef "${PFSDIR}/mount/${pack}/pfs.files" -n >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    [ -f "/tmp/.pfs/install/${bsname}/${pack}${PFSDIR}/mount/${pack}/pfs.files" ] && cat "/tmp/.pfs/install/${bsname}/${pack}${PFSDIR}/mount/${pack}/pfs.files" 2>/dev/null | sed -e 's:^[^/]*::' -e 's:[\]:\\\\\\\\:g'
  fi
  rm -rf "/tmp/.pfs/install/${bsname}/${pack}" 2>/dev/null
  unsquashfs -l "${instfile}" 2>/dev/null | grep -q "${PFSDIR}/mount/${pack}/pfs.dirs.empty"
  if [ $? -eq 0 ]; then
    unsquashfs -d "/tmp/.pfs/install/${bsname}/${pack}" "${instfile}" -ef "${PFSDIR}/mount/${pack}/pfs.dirs.empty" -n >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      if [ -f "/tmp/.pfs/install/${bsname}/${pack}${PFSDIR}/mount/${pack}/pfs.dirs.empty" ]; then
        cat "/tmp/.pfs/install/${bsname}/${pack}${PFSDIR}/mount/${pack}/pfs.dirs.empty" 2>/dev/null | sed -e 's:^[^/]*::' -e 's:[\]:\\\\\\\\:g' -e 's:[/*]$::g' | while read dirempty; do mkdir -p "${dirempty}"; done
      fi
    fi
  fi
  rm -rf "/tmp/.pfs/install/${bsname}/${pack}" 2>/dev/null
  unsquashfs -d "/tmp/.pfs/install/${bsname}/${pack}" "${instfile}" -ef "${PFSDIR}/mount/${pack}" -n >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    if [ -d "/tmp/.pfs/install/${bsname}/${pack}${PFSDIR}/mount/${pack}" ]; then
      [ -d "${PFSDIR}/install/${pack}" ] && rm -rf "${PFSDIR}/install/${pack}"
      mkdir -p "${PFSDIR}/install" 
      cp -a "/tmp/.pfs/install/${bsname}/${pack}${PFSDIR}/mount/${pack}" "${PFSDIR}/install/${pack}"
    fi
  fi
  rm -rf "/tmp/.pfs/install/${bsname}/${pack}" 2>/dev/null
done`"

# с пустым allfiles завершается без ошибок, надо поправить
if [ "${allfiles}" != "" ]; then
  if echo "${allfiles}" | grep -q -F '\'; then
    unsquashfs -d "/tmp/.pfs/install/${bsname}/tmp" "${instfile}" >/dev/null 2>&1
    status=$?
    allunpack="yes"
  fi
  echo "${allfiles}" | grep . | while read file
  do
    if [ "${allunpack}" != "yes" ]; then
      unsquashfs -d "/tmp/.pfs/install/${bsname}/tmp" "${instfile}" -ef "$(echo "${file}" | sed -e 's/\[/\\\[/g')" -n >/dev/null 2>&1
      status=$?
    fi
    if [ ${status} -eq 0 ]; then    
      cpnamedir="$(dirname "${file}")"
      mkdir -p "${cpnamedir}"
      mv -f "/tmp/.pfs/install/${bsname}/tmp${file}" "${cpnamedir}"
      status=$?
    fi
    [ "${allunpack}" != "yes" ] && rm -rf "/tmp/.pfs/install/${bsname}/tmp" 2>/dev/null
    if [ ${status} -gt 0 ]; then
      exit ${status}
    fi
  done
  status=$?
fi

rm -rf "/tmp/.pfs/install/${bsname}" 2>/dev/null
[ ${status} -gt 0 ] && echo "Install error!" >&2

exit ${status}