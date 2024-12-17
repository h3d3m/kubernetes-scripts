#!/bin/bash
set -euo pipefail

WARNING="\033[31m[WARNING]\033[0m"
OK="\033[32mOK\033[0m"
OUT_DIR="/var/lib/kubernetes"

trap 'echo -e "${WARNING}: Something went wrong in ${BASH_COMMAND}"' ERR

generate_encryption_config() {
	local DIR=$1
	local KEY=$(head -c 32 /dev/urandom | base64)

	echo "---"
	echo "Generating encryption config..."
	cat > ${DIR}/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${KEY}
      - identity: {}
EOF
	echo -e "${OK}"
}

if [[ -d "${OUT_DIR}" ]]; then
	rm -f ${OUT_DIR}/encryption-config.yaml
	generate_encryption_config ${OUT_DIR}
else
	echo -e "${WARNING}: Can't find ${OUT_DIR} directory"
	exit 1
fi
