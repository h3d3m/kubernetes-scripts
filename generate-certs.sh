#!/bin/bash
set -euo pipefail

WARNING="\033[31m[WARNING]\033[0m"
OK="\033[32mOK\033[0m"
ENV_FILE="k8s.yaml"
OUT_DIR="/var/lib/kubernetes/pki"

generate_certificate() {
	local DIR=$1
	local NAME=$2
	local SUBJ=$(yq e ".cluster.certificates[] | select(.name == \"${NAME}\").subject" ${ENV_FILE})
	
	echo "---"
	echo "Generating ${NAME} key and certificate..."
	openssl genrsa -out ${DIR}/${NAME}.key 2048
	openssl req -new -key ${DIR}/${NAME}.key -subj "${SUBJ}" -out ${DIR}/${NAME}.csr
	if [[ "${NAME}" == "ca" ]]; then
		if openssl x509 -req -in ${DIR}/${NAME}.csr -signkey ${DIR}/${NAME}.key -out ${DIR}/${NAME}.crt -days 1000 &> /dev/null; then
			rm -f ${DIR}/${NAME}.csr
			echo -e "${OK}"
		fi
	elif [[ "${NAME}" == "kube-apiserver" ]] || [[ "${NAME}" == "apiserver-kubelet-client" ]] || [[ "${NAME}" == "etcd-server" ]]; then
		generate_config ${DIR} ${NAME}
		if openssl x509 -req -in ${DIR}/${NAME}.csr -CA ${DIR}/ca.crt -CAkey ${DIR}/ca.key -CAcreateserial -out ${DIR}/${NAME}.crt -extensions v3_req -extfile ${DIR}/${NAME}.cnf -days 1000 &> /dev/null; then
			rm -f ${DIR}/${NAME}.csr ${DIR}/${NAME}.cnf
			echo -e "${OK}"
		fi
	else
		if openssl x509 -req -in ${DIR}/${NAME}.csr -CA ${DIR}/ca.crt -CAkey ${DIR}/ca.key -CAcreateserial -out ${DIR}/${NAME}.crt -days 1000 &> /dev/null; then
			rm -f ${DIR}/${NAME}.csr
			echo -e "${OK}"
		fi
	fi
}

generate_config() {
	local DIR=$1
	local NAME=$2
	
	if [[ "${NAME}" == "kube-apiserver" ]]; then
		cat > ${DIR}/${NAME}.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster
DNS.5 = kubernetes.default.svc.cluster.local
IP.1 = $(yq e ".cluster.ips[] | select(.name == \"service_api\").value" ${ENV_FILE})
IP.2 = $(yq e ".cluster.ips[] | select(.name == \"controlplain01\").value" ${ENV_FILE})
IP.3 = $(yq e ".cluster.ips[] | select(.name == \"controlplain02\").value" ${ENV_FILE})
IP.4 = $(yq e ".cluster.ips[] | select(.name == \"loadbalancer\").value" ${ENV_FILE})
IP.5 = 127.0.0.1
EOF
	elif [[ "${NAME}" == "apiserver-kubelet-client" ]]; then
		cat > ${DIR}/${NAME}.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF
	elif [[ "${NAME}" == "etcd-server" ]]; then
		cat > ${DIR}/${NAME}.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = $(yq e ".cluster.ips[] | select(.name == \"controlplain01\").value" ${ENV_FILE})
IP.2 = $(yq e ".cluster.ips[] | select(.name == \"controlplain02\").value" ${ENV_FILE})
IP.3 = 127.0.0.1
EOF
	fi
}

if [[ -f "${ENV_FILE}" ]]; then
	NAMES=$(yq e ".cluster.certificates[].name" ${ENV_FILE})
	if [[ -d "${OUT_DIR}" ]]; then
		rm -rf ${OUT_DIR}/*
	else
		mkdir -p ${OUT_DIR}
	fi
	for NAME in ${NAMES}; do
		generate_certificate ${OUT_DIR}	${NAME}
	done
else
	echo -e "${WARNING}: Can't find ${ENV_FILE} file"
	exit 1
fi
