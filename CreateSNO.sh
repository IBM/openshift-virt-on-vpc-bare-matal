#!/bin/bash

# 1. Update the Inputs
# 2. chmod +x CreateSNO.sh
# 3. Login to the IBM CLoud with the CLI e.g. ibmcloud login -sso
# 4. Run this script ./CreateSNO.sh

# Inputs

## Place the path to the ssh public key that you want to use
my_public_ssh_key_path="<PATH_TO_YOUR_PUBLIC_KEY>"

## Place your ISO URL from the Red Hat Hybrid Cloud Console
iso_url="<URL_TO_ISO>"

## Place your cluster name and base domain from the Red Hat Hybrid Cloud Console
my_cluster_name="demo-01"
my_base_domain="demo.cloud"

## If you want a Floating IP address created so you can access the console via the Internet then use yes below
create_fip="yes"

## Create the following resources? If no, the script will expect them to be already created
create_resource_group="yes"
create_vpc="yes"
create_subnet="yes"
create_security_group="yes"
create_public_ssh_key="yes"

## The following do not need to be changed unless you want to
target_resource_group="demo-ocp-rg"
target_region="us-south"
target_zone="us-south-1"
target_vpc_name="demo-sno"
target_pgw_name="demo-sno-pgw"
target_address_prefix_name="demo-sno-prefix-1"
target_subnet_name="demo-sno-sn-1"
target_subnet_cidr="192.168.99.0/24"
target_security_group_name="demo-sno-sg"
target_bare_metal_hostname_short="demo-1"
target_bare_metal_profile="bx3d-metal-48x256"
target_ssh_key_name="demo-key"
target_os_image_name="ibm-ipxe-20240326-amd64-1"
target_fip_name="demo-fip"
sno_userdata_file="demo-userdata.txt"
log_file_path="CreateSNO.log"

# DO NOT CHANGE ANYTHING BELOW HERE

# Show the parameters and confim to proceed
echo ""
echo "This script will create a Red Hat Openshift Single Node cluster on an IBM Cloud VPC Bare Metal Server with the following parameters:"
echo "  create_resource_group:            $create_resource_group"
echo "  create_vpc:                       $create_vpc"
echo "  create_subnet:                    $create_subnet"
echo "  create_security_group:            $create_subnet"
echo "  create_public_ssh_key:            $create_public_ssh_key"
echo "  create_fip:                       $create_fip"
echo "  my_cluster_name:                  $my_cluster_name"
echo "  my_base_domain:                   $my_base_domain"
echo "  my_public_ssh_key_path:           $my_public_ssh_key_path"
echo "  target_resource_group:            $target_resource_group"
echo "  target_region:                    $target_region"
echo "  target_zone:                      $target_zone"
echo "  target_vpc_name:                  $target_vpc_name"
echo "  target_pgw_name:                  $target_pgw_name"
echo "  target_address_prefix_name:       $target_address_prefix_name"
echo "  target_subnet_name:               $target_subnet_name"
echo "  target_subnet_cidr:               $target_subnet_cidr"
echo "  target_security_group_name:       $target_security_group_name"
echo "  target_bare_metal_hostname_short: $target_bare_metal_hostname_short"
echo "  target_bare_metal_profile:        $target_bare_metal_profile"
echo "  target_ssh_key_name:              $target_ssh_key_name"
echo "  target_os_image_name:             $target_os_image_name"
echo "  target_fip_name:                  $target_fip_name"
echo "  sno_userdata_file:                $sno_userdata_file"
echo "  log_file_path:                    $log_file_path"
echo ""
echo "Do you want to use the parameters above? Type yes to proceed, no to quit."
read confirm
if [ "$confirm" != "yes" ]
then
    exit 0
fi

# Create the log file
echo "Creating the log file $log_file_path"
echo Start time: `date` > $log_file_path

# Create the userdata file
echo "Creating the user-data file $sno_userdata_file" | tee -a $log_file_path

cat > $sno_userdata_file <<EOF
#!ipxe
:retry_dhcp
dhcp || goto retry_dhcp
sleep 2
ntp time.adn.networklayer.com
sanboot ${iso_url}
EOF

echo "Created the user-data file $sno_userdata_file" | tee -a $log_file_path

# Get my external IP for use in the security group when a Floating IP is used for external connection to the cluster
if [[ $create_fip == "yes" ]]
then
    echo "Getting the external IP address" | tee -a $log_file_path
    my_ip=$(curl -s -4 ifconfig.me)
    echo "my_ip: $my_ip" | tee -a $log_file_path
fi

## Make sure we are loggged in
if ibmcloud is --help >> /dev/null 2>&1
then
    echo "Success: We are logged into the ibmcloud CLI" | tee -a $log_file_path
else
    echo "Failed: Not logged into the ibmcloud CLI. Use ibmcloud login" | tee -a $log_file_path
    exit 1
fi

# Target the required region
if ibmcloud target -r $target_region --quiet >> $log_file_path
then
    echo "Success: Targeting $target_region" | tee -a $log_file_path
else
    echo "Failed: Unable to target $target_region" | tee -a $log_file_path
    exit 1
fi

# Create the resource group
if [[ $create_resource_group = "yes" ]]
then
    echo "Creating resource group $target_resource_group" | tee -a $log_file_path
    if ibmcloud resource group-create $target_resource_group --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the resource group $target_resource_group" | tee -a $log_file_path
    else
        echo "Failed: Unable to create resource group $target_resource_group. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
else
    echo "Not creating resource group $target_resource_group" | tee -a $log_file_path
fi

# Target the resource group
echo "Targeting the resource group $target_resource_group" | tee -a $log_file_path
if ibmcloud target -g $target_resource_group --quiet >> $log_file_path 2>&1
then
    echo "Success: Targeting the resource group $target_resource_group" | tee -a $log_file_path
else
    echo "Failed: Unable to target resource group $target_resource_group. View $log_file_path" | tee -a $log_file_path
    exit 1
fi

# Create the VPC
if [[ $create_vpc = "yes" ]]
then
    echo "Creating the VPC $target_vpc_name" | tee -a $log_file_path
    if ibmcloud is vpc-create $target_vpc_name --address-prefix-management manual --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the VPC $target_vpc_name" | tee -a $log_file_path
    else
        echo "Failed: Unable to create VPC $target_vpc_name. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
else
    echo "Not creating VPC $target_vpc_name" | tee -a $log_file_path
fi

# Create the public gateway to allow outbound connections to the Internet, address prefix and subnet
if [[ $create_subnet = "yes" ]]
then
    echo "Creating the public gateway $target_pgw_name" | tee -a $log_file_path
    if ibmcloud is public-gateway-create $target_pgw_name $target_vpc_name $target_zone --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the public gateway $target_pgw_name" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the public gateway $target_pgw_name. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
    echo "Creating the address prefix $target_address_prefix_name" | tee -a $log_file_path
    if ibmcloud is vpc-address-prefix-create $target_address_prefix_name $target_vpc_name $target_zone $target_subnet_cidr --default true --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the address prefix $target_address_prefix_name" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the address prefix $target_address_prefix_name. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
    echo "Creating the subnet $target_subnet_name" | tee -a $log_file_path
    if ibmcloud is subnet-create $target_subnet_name $target_vpc_name --ipv4-cidr-block $target_subnet_cidr --zone $target_zone --pgw $target_pgw_name --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the subnet $target_subnet_name" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the subnet $target_subnet_name. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
else
    echo "Not creating subnet $target_subnet_name" | tee -a $log_file_path
fi

# Verify public gateway is attached to the subnet
verify_pgw_name=$(ibmcloud is subnet $target_subnet_name --output json | jq -r '(.public_gateway.name)')
if [[ $verify_pgw_name = $target_pgw_name ]]
then
    echo "Success: Public gateway $target_pgw_name is connected to subnet $target_subnet_name" | tee -a $log_file_path
else
    echo "Failed: Public gateway $target_pgw_name is NOT connected to subnet $target_subnet_name" | tee -a $log_file_path
    exit 1
fi

# Create the security group and rules
if [[ $create_security_group = "yes" ]]
then
    echo "Creating the security group $target_security_group_name" | tee -a $log_file_path
    if ibmcloud is security-group-create $target_security_group_name --vpc $target_vpc_name --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the security group $target_security_group_name" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the security group $target_security_group_name. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
    echo "Creating the security group rule to allow communication between processes on the SNO" | tee -a $log_file_path
    if ibmcloud is security-group-rule-add $target_security_group_name inbound all --remote $target_security_group_name --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the security group rule" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the security group rule. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
    echo "Creating the security group rule to allow inbound TCP on port 443 from $my_ip/32" | tee -a $log_file_path
    if ibmcloud is security-group-rule-add $target_security_group_name inbound tcp --port-min 443 --port-max 443 --remote "$my_ip/32" --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the security group rule" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the security group rule. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
    echo "Creating the security group rule to allow inbound TCP on port 6443 from $my_ip/32" | tee -a $log_file_path
    if ibmcloud is security-group-rule-add $target_security_group_name inbound tcp --port-min 6443 --port-max 6443 --remote "$my_ip/32" --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the security group rule" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the security group rule. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
    echo "Creating the security group rule to allow inbound ICMP pings from $my_ip/32" | tee -a $log_file_path
    if ibmcloud is security-group-rule-add $target_security_group_name inbound icmp --icmp-type 8 --icmp-code 0 --remote "$my_ip/32" --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the security group rule" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the security group rule. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
    echo "Creating the security group rule to allow all outbound traffic" | tee -a $log_file_path
    if ibmcloud is security-group-rule-add "$target_security_group_name" outbound all --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the security group rule" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the security group rule. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
else
    echo "Not creating the security group $target_security_group_name" | tee -a $log_file_path
fi

# Create a SSH Key
if [[ $create_public_ssh_key = "yes" ]]
then
    echo "Creating the public SSH key $target_ssh_key_name from $my_public_ssh_key_path" | tee -a $log_file_path
    if ibmcloud is key-create $target_ssh_key_name @$my_public_ssh_key_path --quiet >> $log_file_path 2>&1
    then
        echo "Success: Created the public SSH key $target_ssh_key_name" | tee -a $log_file_path
    else
        echo "Failed: Unable to create the public SSH key $target_ssh_key_name. View $log_file_path" | tee -a $log_file_path
        exit 1
    fi
else
    echo "Not creating the public SSH key $my_ssh_key_name" | tee -a $log_file_path
fi

# Create IBM Cloud Bare Metal
echo "Creating the bare metal server $target_bare_metal_hostname_short" | tee -a $log_file_path
if ibmcloud is bare-metal-server-create \
--name $target_bare_metal_hostname_short \
--resource-group-name $target_resource_group \
--vpc $target_vpc_name \
--zone $target_zone \
--pnac-name "$target_bare_metal_hostname_short-vni-pci1-attach" \
--pnac-vni-name "$target_bare_metal_hostname_short-vni-pci1" \
--pnac-vni-subnet $target_subnet_name \
--pnac-vni-sgs $target_security_group_name \
--profile $target_bare_metal_profile \
--image $target_os_image_name \
--keys $target_ssh_key_name \
--user-data @$sno_userdata_file --quiet >> $log_file_path 2>&1
then
    echo "Success: Created the bare metal server $target_bare_metal_hostname_short" | tee -a $log_file_path
else
    echo "Failed: Unable to create the bare metal server $target_bare_metal_hostname_short. View $log_file_path" | tee -a $log_file_path
    exit 1
fi

# Verify the bare metal server enters the Running state
bm_create_status="pending"
while [[ ! $(echo $bm_create_status | grep running) ]]
do
    echo "Bare metal server $target_bare_metal_hostname_short is not in status Running, waiting 30 seconds. Current status is '$bm_create_status'"
    sleep 30
    bm_create_status=$(ibmcloud is bare-metal-server $target_bare_metal_hostname_short | grep Status | awk '{print $2}')
    if [[ $(echo $bm_create_status | grep failed) ]] ; then echo "Bare Metal has failed, exit script" && exit 1 ; fi
done
echo "Bare metal server $target_bare_metal_hostname_short is now in status '$bm_create_status'"

# Create a Floating IP
if [[ $create_fip = "yes" ]]
then
    echo "Creating a Floating IP" | tee -a $log_file_path
    fip=$(ibmcloud is floating-ip-reserve $target_fip_name --vni "$target_bare_metal_hostname_short-vni-pci1" --output JSON | jq -r '(.address)')

    echo "Return to the Red Hat Hybrid Cloud Console to see the installation progress and get your username and password."
    echo "If you are connecting via a Floating IP, then disregard the IPs displayed on the Console and add the following to your hosts file:"
    echo ""
    echo "$fip	api.$my_cluster_name.$my_base_domain"
    echo "$fip	oauth-openshift.apps.$my_cluster_name.$my_base_domain"
    echo "$fip	console-openshift-console.apps.$my_cluster_name.$my_base_domain"
    echo "$fip	grafana-openshift-monitoring.apps.$my_cluster_name.$my_base_domain"
    echo "$fip	thanos-querier-openshift-monitoring.apps.$my_cluster_name.$my_base_domain"
    echo "$fip	prometheus-k8s-openshift-monitoring.apps.$my_cluster_name.$my_base_domain"
    echo "$fip	alertmanager-main-openshift-monitoring.apps.$my_cluster_name.$my_base_domain"
    echo ""
    echo "When the install is complete, using a browser, navigate to: https://console-openshift-console.apps.$my_cluster_name.$my_base_domain"
    echo "You will need to make the lvms-vg1 StorageClass default with the command after logging in: oc patch storageclass lvms-vg1 -p '{\"metadata\": {\"annotations\": {\"storageclass.kubernetes.io/is-default-class\": \"true\"}}}'"
else
    echo "Return to the Red Hat Hybrid Cloud Console to see the installation progress and get your username and password."
fi
echo ""
echo "When you have finished the demo use the following to destroy the resources:"
echo ""
echo "ibmcloud target -r $target_region"
echo "ibmcloud target -g $target_resource_group"
echo "ibmcloud is floating-ip-release $target_fip_name --force" | tee DeleteSNO.sh
echo "ibmcloud is bare-metal-server-stop $target_bare_metal_hostname_short --force" | tee -a DeleteSNO.sh
echo "bm_create_status=\"running\"" | tee -a DeleteSNO.sh
echo 'while [[ ! $(echo $bm_create_status | grep stopped) ]]' | tee -a DeleteSNO.sh
echo "do " | tee -a DeleteSNO.sh
echo "    echo \"Bare metal server $target_bare_metal_hostname_short is not in status Stopped, waiting 30 seconds. Current status is '$bm_create_status'\"" | tee -a DeleteSNO.sh
echo "    sleep 30 " | tee -a DeleteSNO.sh
echo "    bm_create_status=\$(ibmcloud is bare-metal-server $target_bare_metal_hostname_short | grep Status | awk '{print $2}')" | tee -a DeleteSNO.sh
echo '    if [[ $(echo $bm_create_status | grep failed) ]] ; then echo \"Bare Metal has failed, exit script\" && exit 1 ; fi' | tee -a DeleteSNO.sh
echo "done" | tee -a DeleteSNO.sh
echo "ibmcloud is bare-metal-server-delete $target_bare_metal_hostname_short --force" | tee -a DeleteSNO.sh
echo "ibmcloud is key-delete $target_ssh_key_name --force" | tee -a DeleteSNO.sh
echo "ibmcloud is security-group-delete $target_security_group_name --force" | tee -a DeleteSNO.sh
echo "ibmcloud is subnet-delete $target_subnet_name --force" | tee -a DeleteSNO.sh
echo "ibmcloud is public-gateway-delete $target_pgw_name --force" | tee -a DeleteSNO.sh
echo "ibmcloud is vpc-delete $target_vpc_name --force" | tee -a DeleteSNO.sh
echo "ibmcloud resource group-delete $target_resource_group --force" | tee -a DeleteSNO.sh
echo ""
echo "This has been saved as DeleteSNO.sh. Run chmod +x DeleteSNO.sh and then ./DeleteSNO.sh to destroy"
echo "Archive the cluster on the Red Hat Hybrid Cloud Console"
echo "echo \"Archive the cluster on the Red Hat Hybrid Cloud Console\"" >> DeleteSNO.sh
exit 0
