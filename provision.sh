#/bin/bash

if [ "$(which az)" = "" ]
then
    echo Azure CLI not found, installing now...
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
    echo Azure CLI found, continuing...
fi

if [ $(az account show -o tsv --query id 2>&1 |wc -c) -eq 40 ]
then
    echo -e \\n please follow the instructions below to connect to your Azure subscription...
    az login -o tsv
fi

# variables - must set-up
rgName=myrg
location=southindia
vnetName=myvnet
subnetDMZ=dmz-subnet
subnetApps=apps-subnet
subnetCommmon=common-subnet
adminUser=vmadmin
adminPassword=Pa55w0rd@312
storageType=Standard_LRS
fileshareName=azfileshare8bf

# change and reset this variable as needed
#storageType=Premium_LRS

# change and reset this variable as needed
# Ubuntu 18.04.3 LTS
image18=Canonical:UbuntuServer:18.04-LTS:18.04.201908131
# Ubuntu 16.04.5 LTS
image16=Canonical:UbuntuServer:16.04-LTS:16.04.201807240

image=$(echo $image18)

# sourcing function for repeat operations
source functions.sh

# README
# call this function to create the resource group and vnet
# createbaseinfra resource-group-nane location vnet-name vnet-cidr-address-range

# call this function to create the resource group and vnet
# createsubnet name-of-subnet vnet-name subnet-cidr-address-range nsg-ports-to-open

# call functions to create VMs with internal or external load balancer (L4)
# createextlb/createintlb lb-name subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed

# call this function to create VMs with public application gateway (L7)
# createappgw appgw-name subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed

# call this function to create VMs with internal application gateway (L7)
# createintappgw appgw-name subnet-name vm-name-prefix number-of-vms vm-size os-disks-size data-disk-size ports-for-appgw-rules

# call this function to create standalone VMs - no lb/appgw
# createvms vm-name-prefix subnet-name number-of-vm vm-size os-disk-size data-disk-size public-ip-if-needed

# creation starts from here

# creating resource group and virtual network
createbaseinfra $rgName $location $vnetName 10.0.0.0/16

# creating subnet and associated network security group 
createsubnet $subnetDMZ $vnetName 10.0.1.0/24 "22 443"
createsubnet $subnetApps $vnetName 10.0.2.0/24 "22 443"
createsubnet $subnetCommmon $vnetName 10.0.3.0/24 "22 443"

echo -e \\n creating storage and file share...
az storage account create -n $fileshareName -g $rgName -l $location --sku Standard_LRS
az storage share create --account-name $fileshareName --name $fileshareName

echo -e \\n current status of deployments...
az group deployment list -g $rgName -o table

echo -e \\n please run the following command to check the status of all deployments...
echo -e \\n az group deployment list -g $rgName -o table
