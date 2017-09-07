#!/bin/bash
function generate_asn_filter() {
  local as="$1"
  echo "Generating filter for $as"
  local whois=$(whois -h whois.radb.net -- -i origin -T $ROUTE_TYPE AS$as)
  local filter_text="filter ${ROUTE_TYPE}_${as} {"
  # Parse the whois information
  while read line; do
    if [[ "$line" =~ ^$ROUTE_TYPE\:* ]]; then
	  line="${line/$ROUTE_TYPE:/}"
	  line="${line//[[:space:]]/}"
	  echo "--- Adding $line"
	  filter_text+="\nif net = $line then accept;"
	fi
  done <<< "$whois"
  filter_text+="\nreject;\n}"
  echo -e "$filter_text" > "$TARGET/${ROUTE_TYPE}_${as}.conf"
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

if [ -z "$ASN" ]; then
  exit 1
fi

if [ "$IPv6" = true ]; then
  ROUTE_TYPE="route6"
else
  ROUTE_TYPE="route"
fi

for as in "${ASN[@]}"; do
  generate_asn_filter $as
done

