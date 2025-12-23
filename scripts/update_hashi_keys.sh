#!/bin/bash

# Vars:
VAULT_ADDR="https://vault.example.com"

read_password() {
	local prompt=$1
	local password=""
	read -s -p "$prompt" password
	echo "$password"
}

validate_token() {
	local token=$1
	local response=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Vault-Token: $token" $VAULT_ADDR/v1/auth/token/lookup-self)
	if [ $response -eq 200 ]; then
		echo "Valid vault token: $token"
		return 0
	else
		echo "Invalid vault token: $token"
		return 1
	fi
}

VAULT_TOKEN=$(read_password "Enter the vault token: ")
echo ""

while ! validate_token $VAULT_TOKEN; do
	VAULT_TOKEN=$(read_password "Enter a new vault token: ")
	echo ""
done

update_key() {
	local key_name=$1
	local password=$2
	curl -X POST -H "X-Vault-Token: $VAULT_TOKEN" -d "{\"value\": \"$password\"}" $VAULT_ADDR/v1/secret/data/$key_name
}

validate_key() {
	local key_name=$1
	local response=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/secret/data/$key_name)
	if [ $response -eq 200 ]; then
		echo "Valid key name: $key_name"
		return 0
	else
		echo "Invalid key name: $key_name"
		return 1
	fi
}

compare_passwords() {
	local password1=$1
	local password2=$2
	if [ "$password1" == "$password2" ]; then
		echo "Passwords match"
		return 0
	else
		echo "Passwords do not match"
		return 1
	fi
}

read -p "How many keys do you want to update? " num_keys

while ! [[ "$num_keys" =~ ^[1-9][0-9]*$ ]]; do
	echo "Invalid number of keys: $num_keys"
	read -p "Enter a positive integer: " num_keys
done

for ((i = 1; i <= num_keys; i++)); do

	read -p "Enter a key name for key #$i: " key_name

	while ! validate_key $key_name; do
		read -p "Enter a new key name for key #$i: " key_name
	done

	password1=$(read_password "Enter a password for $key_name: ")
	echo ""
	password2=$(read_password "Re-enter the password for $key_name: ")
	echo ""

	while ! compare_passwords $password1 $password2; do
		password1=$(read_password "Enter a new password for $key_name: ")
		echo ""
		password2=$(read_password "Re-enter the new password for $key_name: ")
		echo ""
	done

	update_key $key_name $password1

done

echo "All keys updated successfully"
