#!/bin/bash

sqloperatorchart='https://presslabs.github.io/charts'
kubespray_inventory='/root/kubespray/inventory/mycluster/inventory.ini'
nginx_ingress_link='https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.41.2/deploy/static/provider/baremetal/deploy.yaml'

RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m" # No Color

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# Functions

install_mysql() {
  if [[ "x$1" == "x" ]]
  then
  size=5
  fi

for i in $( kubectl get nodes |grep node|  grep -iv master | awk '{print $1}' ); do kubectl label nodes $i role=worker; done

sed -i "s|STORAGE_SIZE|${1}|g" ${CUR_DIR}/vars_dir/pv.yaml
sed -i "s|STORAGE_PATH|/var/lib/mysql|g" ${CUR_DIR}/vars_dir/pv.yaml

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook --private-key $2 -i $3 sql_dirs.yaml -e ignore_assert_errors=yes

helm repo add presslabs $sqloperatorchart && helm pull presslabs/mysql-operator --untar

cp -f ${CUR_DIR}/vars_dir/values.yaml ${CUR_DIR}/mysql-operator/values.yaml

kubectl create -f ${CUR_DIR}/vars_dir/storage-class.yaml
kubectl create -f ${CUR_DIR}/vars_dir/pv.yaml
#kubectl create -f ${CUR_DIR}/vars_dir/pvc.yaml

sleep 15

helm install mysql-operator-release ${CUR_DIR}/mysql-operator

echo -e "${GREEN} Congratz! The MySQL operator has been deployed, MySQL cluster sample - ${CUR_DIR}/vars_dir/mysqlcluster.yaml  ${NC}"

}


install_nginx() {

kubectl apply -f $nginx_ingress_link && sleep 30 && kubectl -n ingress-nginx  patch deployment  ingress-nginx-controller  -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'

echo -e "${GREEN} Congratz! The Nginx Ingress controller has been deployed, Ingress sample - ${CUR_DIR}/vars_dir/host-based-ingress.yaml  ${NC}"
}



##############################################################################
##############################################################################
##############################################################################
#############################    BODY     ####################################
##############################################################################
##############################################################################
##############################################################################

kubectl get nodes  >/dev/null 2>&1  || { echo -e " ${RED} kubectl does not work, exiting ${NC}" ; exit 1; }



while true; do
read -rp "$(echo -e ${GREEN} Please specify the full path to the private key file ${NC})" full_path
if [ -f "$full_path" ];
then
echo -e "${GREEN} The $full_path exists, proceeding ${NC}"

read -rp "$(echo -e ${GREEN} Please specify the full path to the Ansible inventory file, if not, the one for Kubespray will be used  ${NC} )" inventory_path
if [ -f "$inventory_path" ];
then
echo -e "${GREEN} The $inventory_path exists, proceeding ${NC}"
else
echo -e "${RED} The $inventory_path file does not exist, will use the $kubespray_inventory one${NC}"
inventory_path=${kubespray_inventory}
fi
break
else
echo -e "${RED} The $full_path private key does not exist, please specify the correct path to it ${NC}"
fi
done







while true; do

read -rp "$(echo -e ${GREEN} Do you wish to install mysql-operator, it will be installed on all worker nodes [Y/n] ${NC})" muskul

case $muskul in
  [nN]* )
        echo "====================================================================================="
        echo -e "${GREEN} MySQL operator/cluster deployment skipped ${NC}"
        echo "=====================================================================================";
        break;;
  [yY]* )
      echo "======================================================================================="
      echo -e "${GREEN} Proceeding with MySQL operator/cluster installation ${NC}"
      echo "======================================================================================="
      while true; do
      read -rp "$(echo -e ${GREEN} Please specify the size of the volume for MySQL, default - 5Gb ${NC})" muskul_size
      if [[ $muskul_size =~ ^[0-9]{1,3}$ ]]
      then
      echo -e "${GREEN} Volume size $muskul_size is valid ${NC}"
      install_mysql $muskul_size $full_path $inventory_path
      break
      else
      echo -e "${RED} Volume size $muskul_size is invalid ${NC}"
      fi
      done
      break;;

   * )
      echo -e "${RED} Please answer yes or no ${NC}";;
      esac
done

while true; do
  read -rp "$(echo -e ${GREEN} Do you wish to install Nginx ingress [Y/n] ${NC} )" ngix

  case $ngix in
    [nN]* )
          echo "====================================================================================="
          echo -e "${GREEN} Nginx ingress controller deployment skipped ${NC}"
          echo "=====================================================================================";
          break;;
    [yY]* )
        echo "======================================================================================="
        echo -e "${GREEN} Proceeding with Nginx ingress installation ${NC}"
        echo "======================================================================================="

        # read -rp "$(echo -e ${GREEN} If you wish to create Ingress resource for the domain also, please specify the domain, pointed to this cluster  ${NC} )" domain
        # if [[ $domain ~= (?=^.{1,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$) ]]
        # then
        # echo -e "${GREEN} The $domain is valid, proceeding ${NC}"
        # domain_valid=1
        # else
        # echo -e "${RED} The $domain is not valid or was not specified, skipped ${NC}"
        # fi
        install_nginx ${domain_valid} $domain

        break;;
     * ) echo -e "${RED} Please answer yes or no ${NC}";;
        esac
done
