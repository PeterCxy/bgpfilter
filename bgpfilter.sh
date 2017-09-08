#!/bin/bash
ASN_FILTER=""
function generate_asn_filter() {
  local as="$1"
  local fullconf="$2"
  echo "Generating filter for $as"
  local whois=$(whois -h whois.radb.net -- -i origin -T $ROUTE_TYPE AS$as)
  local filter_text=""
  if [[ "$fullconf" == "true" ]]; then
    filter_text="function ${ROUTE_TYPE}_${as}() {"
  fi
  # Parse the whois information
  while read line; do
    if [[ "$line" =~ ^$ROUTE_TYPE\:* ]]; then
      line="${line/$ROUTE_TYPE:/}"
      line="${line//[[:space:]]/}"
      echo "--- Adding $line"
      filter_text+="\nif net = $line then return true;"
    fi
  done <<< "$whois"
  if [[ "$fullconf" == "true" ]]; then
    filter_text+="\nreturn false;\n}"
    echo -e "$filter_text" > "$TARGET/${ROUTE_TYPE}_${as}.conf"
  else
    ASN_FILTER="$filter_text"
  fi
}

EXPANDED_ASN=()
EXPANDED_SET=()
function expand_as_set() {
  local as_set="$1"
  if [[ "${EXPANDED_SET[@]}" =~ "$as_set" ]]; then
    echo "Duplicate $as_set. Skipping."
	return
  fi
  EXPANDED_SET+=("$as_set")
  echo "Loading $as_set"
  local whois=$(whois -h whois.radb.net $as_set)
  # Parse the whois information
  while read line; do
    if [[ "$line" =~ ^members\:* ]]; then
      line="${line/members:/}"
      line="${line//[[:space:]]/}"

      # Check if this is aut-num or as-set
      local whois2=$(whois -h whois.radb.net $line)
      if [[ "$whois2" =~ ^aut-num* ]]; then
        echo "ASN: $line"
        if [[ "${EXPANDED_ASN[@]}" =~ "$line" ]]; then
          echo "Duplicate $line. Skipping."
        else
          EXPANDED_ASN+=("${line/AS/}")
        fi
      else
        echo "Looking up: $as_set"
        expand_as_set $line
      fi
    fi
  done <<< "$whois"
}

function generate_set_filter() {
  local as_set="$1"
  echo "Generating filter for $as_set"
  EXPANDED_SET=()
  EXPANDED_ASN=()
  expand_as_set $as_set
  local filter=""
  echo "${EXPANDED_ASN[@]}"
  for as in "${EXPANDED_ASN[@]}"; do
    generate_asn_filter $as false
    filter+="\n$ASN_FILTER"
  done
  echo -e "function ${ROUTE_TYPE}_${as_set//-/_}() {\n$filter\nreturn false;\n}" > "$TARGET/${ROUTE_TYPE}_$as_set.conf"
}

if [ -z "$1" ]; then
  echo "Please specify path to the configuration file"
  exit 1
fi

# Load configuration
source "$1"

if [ -z "$TARGET" ]; then
  exit 1
fi

mkdir -p "$TARGET"

if [ "$IPv6" = true ]; then
  ROUTE_TYPE="route6"
else
  ROUTE_TYPE="route"
fi

if [ ! -z "$ASN" ]; then
  for as in "${ASN[@]}"; do
    generate_asn_filter $as true
  done
fi

if [ ! -z "$AS_SET" ]; then
  for a in "${AS_SET[@]}"; do
    generate_set_filter $a
  done
fi
