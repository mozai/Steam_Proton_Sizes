#!/bin/bash
# list the winebottles for Steam Proton still on disk
# ref. https://redd.it/j81pwg

# requires: bash, cat, du, find, jq, sed, wget, and Steam obviously.

# where your Steam(Proton) games are
steamapps="$HOME/.steam/steam/steamapps"

# if a game was uninstalled, then its name isn't in the local catalog
#  we can fetch a grand list from the moethership and save a local copy
steamappid_url="https://api.steampowered.com/ISteamApps/GetAppList/v2/"
steamappid_cache="$HOME/.cache/steam-appid-list.json"


# I used to launch jq on each query, but that takes too long
declare -A steamappid
load_steamappid_cache(){
	local id name
	found=$(find "$steamappid_cache" -mtime -7 2>/dev/null)
	if [[ -z $found ]]; then
		# cache is over a week old, grab a new one
		rm -f "$steamappid_cache"
		[[ -t 1 ]] && echo "(refreshing $steamappid_cache)"
		wget -q "$steamappid_url" -O "$steamappid_cache"
	fi
	if [[ -e "$steamappid_cache" ]]; then
		[[ -t 1 ]] && echo "(loading Steam appids from cache)"
		while read -r id name; do
			steamappid[$id]=$name
		done < <(<"$steamappid_cache" jq -r '.applist.apps[] |[.appid, .name] |@tsv')
	fi
}

# try translating appid->name, look in multiple places
get_app_name(){
	local id=$1 name=""
	if [[ -e "${steamapps}/appmanifest_${id}.acf" ]]; then
		name=$(sed -n '/^\s*"name"\s*/ s///p' "$steamapps"/appmanifest_"$id".acf)
	fi
	if [[ -z "$name" ]] && [[ -e "$steamappid_cache" ]]; then
		name=${steamappid[$id]}
		[[ -n "$name" ]] && name="$name (uninstalled)"
	fi
	if [[ -z "$name" ]]; then
		name="(no name found)"
	fi
	echo "$name"
}
	
# -- main() --
load_steamappid_cache;
if [[ -t 1 ]]; then
	echo "(Looking through ${steamapps}/compatdata/ )"
	printf "%-10s\t%-13s\t%-5s\t%s\t%s\n" "AppId" "WineVer" "Size" "Name" "Path"
fi
for x in "$steamapps"/compatdata/* ; do
	[[ -d "$x" ]] || echo 2> "(error: \"$x\" is not a directory?)"
	id=${x##*/}
	[[ $id == 0 ]] && continue;
	[[ $id == "pfx" ]] && continue;
	version=$(cat "$x"/version 2>/dev/null)
	size=$(du -sh "$x"); size=${size%$'\t'*}
	name=$(get_app_name "$id")
	printf "%-10s\t%-13s\t%-5s\t%s\t%s\n" "$id" "${version:-unknown}" "$size" "$name" "$x"
done

