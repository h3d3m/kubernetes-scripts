#!/bin/bash
set -euo pipefail

WARNING="\033[31m[WARNING]\033[0m"
OK="\033[32mOK\033[0m"
ENV_FILE="k8s.yaml"
OUT_DIR="/var/lib/kubernetes"

trap 'echo -e "${WARNING}: Something went wrong in ${BASH_COMMAND}"' ERR

generate_kubeconfig() {
	local OUT_DIR=$1
	local NAME=$2

	echo "---"
	echo "Generating kubeconfig for ${NAME}..."
	if [[ "${NAME}" == "kube-proxy" ]]; then
		local LB=$(yq e ".cluster.ips[] | select(.name == \"loadbalancer\").value" ${ENV_FILE})
		kubectl config set-cluster kubernetes-the-hard-way \
    	--certificate-authority=${OUT_DIR}/pki/ca.crt \
    	--server=https://${LB}:6443 \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf

		kubectl config set-credentials system:${NAME} \
    	--client-certificate=${OUT_DIR}/pki/${NAME}.crt \
    	--client-key=${OUT_DIR}/pki/${NAME}.key \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf

		kubectl config set-context default \
    	--cluster=kubernetes-the-hard-way \
    	--user=system:${NAME} \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf
	elif [[ "${NAME}" == "kube-controller-manager" ]] || [[ "${NAME}" == "kube-scheduler" ]]; then	
		kubectl config set-cluster kubernetes-the-hard-way \
    	--certificate-authority=${OUT_DIR}/pki/ca.crt \
    	--server=https://127.0.0.1:6443 \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf

		kubectl config set-credentials system:${NAME} \
    	--client-certificate=${OUT_DIR}/pki/${NAME}.crt \
    	--client-key=${OUT_DIR}/pki/${NAME}.key \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf

		kubectl config set-context default \
    	--cluster=kubernetes-the-hard-way \
    	--user=system:${NAME} \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf
	elif [[ "${NAME}" == "admin" ]]; then
		kubectl config set-cluster kubernetes-the-hard-way \
    	--certificate-authority=${OUT_DIR}/pki/ca.crt \
    	--embed-certs=true \
    	--server=https://127.0.0.1:6443 \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf

  	kubectl config set-credentials ${NAME} \
    	--client-certificate=${OUT_DIR}/pki/${NAME}.crt \
    	--client-key=${OUT_DIR}/pki/${NAME}.key \
    	--embed-certs=true \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf

		kubectl config set-context default \
    	--cluster=kubernetes-the-hard-way \
    	--user=${NAME} \
    	--kubeconfig=${OUT_DIR}/${NAME}.conf
	fi
	kubectl config use-context default --kubeconfig=${OUT_DIR}/${NAME}.conf
	echo -e "${OK}"
}

if [[ -f "${ENV_FILE}" ]]; then
	if [[ -d "${OUT_DIR}" ]]; then
		for NAME in kube-controller-manager kube-proxy kube-scheduler admin; do
			rm -f ${OUT_DIR}/${NAME}.conf
			generate_kubeconfig ${OUT_DIR} ${NAME}
		done
	else
		echo -e "${WARNING}: Can't find ${OUT_DIR} directory"
		exit 1
	fi
else
	echo -e "${WARNING}: Can't find ${ENV_FILE} file"
	exit 1
fi
