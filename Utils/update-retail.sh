#!/bin/bash

retail_dir="/Volumes/Data/Games/World of Warcraft/_retail_/Interface/AddOns/LootRollLedger"
local_dir="LootRollLedger"

if [ ! -d "${local_dir}" ]; then
	echo "error: local directory not found: ${local_dir}"
	exit 1
fi

if [ ! -d "${retail_dir}" ]; then
	echo "error: retail directory not found: ${retail_dir}"
	exit 2
fi

for file in $(ls -1 "${local_dir}"); do
	cp -vf "${local_dir}/${file}" "${retail_dir}"
done
