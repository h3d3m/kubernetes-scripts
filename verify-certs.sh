#!/bin/bash

WARNING="\033[31m[WARNING]\033[0m"
OK="\033[32mOK\033[0m"
ENV_FILE="k8s.yaml"
DIR="/var/lib/kubernetes/pki"

verify_cert() {
	local DIR=$1
	local NAME=$2

	echo "---"
	if [[ -f "${DIR}/${NAME}.crt" ]]; then
		if [[ -f "${DIR}/${NAME}.key" ]]; then					
			local CERT_HASH=$(openssl x509 -noout -modulus -in ${DIR}/${NAME}.crt | openssl md5)
			local KEY_HASH=$(openssl rsa -noout -modulus -in ${DIR}/${NAME}.key | openssl md5)
			if openssl verify -CAfile ${DIR}/ca.crt ${DIR}/${NAME}.crt  &>/dev/null; then
				echo -e "Certificate ${NAME} is ${OK}"
				if [[ "${CERT_HASH} == ${KEY_HASH}" ]]; then
					echo "${NAME} certificate and key match"
				else
					echo -e "${WARNING}: ${NAME} certificate and key don't match"
				fi
			else
				echo -e "${WARNING}: Something wrong with ${NAME} certificate" 
			fi
		else
			echo -e "${WARNING}: Can't find key ${NAME}.key"
		fi
	else
		echo -e "${WARNING}: Can't find certificate ${NAME}.crt"
	fi
}

if [[ -f "${ENV_FILE}" ]]; then
	if [[ -d "${DIR}" ]]; then
		NAMES=$(yq e ".cluster.certificates[].name" ${ENV_FILE})
		for NAME in ${NAMES}; do
			verify_cert ${DIR} ${NAME}
		done
	else
		echo -e "${WARNING}: Can't find ${DIR} directory"
		exit 1
	fi
else
	echo -e "${WARNING}: Can't find ${ENV_FILE} file"
	exit 1
fi
