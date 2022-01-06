#!/bin/bash

# Helper script to patch local addon updates to a 'retail' installation

retail_dir="/Volumes/Games/Games/World of Warcraft/_retail_/Interface/AddOns/LootRollLedger"
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
	diff -q "${local_dir}/${file}" "${retail_dir}"
	is_diff=$?
	if [ ${is_diff} -eq 0 ]; then
		echo "No changes detected for: ${local_dir}/${file}"
	else
		cp -vf "${local_dir}/${file}" "${retail_dir}"
	fi
done
