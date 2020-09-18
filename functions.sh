# creating function for repeat operations

echo "Checking if Azure CLI is installed..."
if [ "$(which az)" = "" ]
then
    echo Azure CLI not found, installing now...
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
    echo Azure CLI found, continuing...
fi

echo "Checking if Azure subscription is connected..."
if [ $(az account show -o tsv --query id 2>&1 |wc -c) -eq 40 ]
then
    echo -e \\n please follow the instructions below to connect to your Azure subscription...
    az login -o tsv
fi

# Sourcing from shell sets up basics and show syntax
if [ "$0" = "-bash" ] || [ "$0" = "/bin/bash" ]  
then
    echo "Setting up the following variables for successful execution of shell functions..."
    echo -e '\t'rgName
    rgName=myrg
    echo -e '\t'location
    location=southindia
    echo -e '\t'vnetName
    vnetName=myvnet
    echo -e '\t'subnetDMZ
    subnetDMZ=dmz-subnet
    echo -e '\t'subnetApps
    subnetApps=apps-subnet
    echo -e '\t'subnetCommmon
    subnetCommmon=common-subnet
    echo -e '\t'adminUser
    adminUser=vmadmin
    echo -e '\t'adminPassword
    adminPassword=Pa55w0rd@312
    echo -e '\t'storageType
    storageType=Standard_LRS
    echo -e '\t'image
    image=UbuntuLTS
    echo -e '\t'fileshareName
    fileshareName=azfileshare8bf
    echo -e \\n"Please change values of these variables as necessary."

    echo -e \\n"Functions:"
    echo -e "Create the resource group and vnet -"
    echo "createbaseinfra resource-group-name location vnet-name vnet-cidr-address-range"

    echo -e \\n"Create the resource group and vnet -"
    echo "createsubnet name-of-subnet vnet-name subnet-cidr-address-range nsg-ports-to-open"

    echo -e \\n"Create standalone VMs - no lb/appgw -"
    echo "createvm vm-name-prefix subnet-name number-of-vm vm-size os-disk-size data-disk-size public-ip-if-needed"

    echo -e \\n"Clone a VM of a running/deallocated VM -"
    echo "clonevm vm-to-be-cloned clone-vm-name-prefix subnet-name number-of-vms vm-size os-disk-size data-disk-sizes public-ip-if-needed"

    echo -e \\n"Create an image of a VM without capturing the original VM -"
    echo "createvmimage vm-name-to-be-imaged subnet-name"

    echo -e \\n"Create a VM Scale Set -"
    echo "createvmss type-of-load-balancer lb-name subnet-name number-of-vms vm-size os-disk-size data-disk-sizes public-ip-if-needed cidr-for-appgw-if-used"

    echo -e \\n"Create VMs with internal load balancer (L4) -"
    echo "createintlb lb-name-prefix subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed"

    echo -e \\n"Create VMs with external load balancer (L4) -"
    echo "createextlb lb-name-prefix subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed"

    echo -e \\n"Create VMs with public application gateway (L7) -"
    echo "createappgw appgw-name subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed"

    echo -e \\n"Create VMs with internal application gateway (L7) -"
    echo "createintappgw appgw-name subnet-name vm-name-prefix number-of-vms vm-size os-disks-size data-disk-size ports-for-appgw-rules"

    echo -e \\n"Add Application Gateway rules for an existing gateway -"
    echo "addappgwrule appgw-name vm-name-prefix ports-for-appgw-rules"

    echo -e \\n"Add Load Balancer (L4) rules -"
    echo "addlbrule lb-name ports-space-separated"

    echo -e \\n"Delete Load Balancer (L4) rules -"
    echo "deletelbrule lb-name ports-space-separated"

    echo -e \\n"Add Network Security Group (nsg) rules -"
    echo "addnsgrule nsg-name ports-space-separated"

    echo -e \\n"Delete Network Security (nsg) rules -"
    echo "deletensgrule nsg-name ports-space-separated"

    echo ""
fi

# create VMs
createvm () {
    vmName=$1
    subnetName=$2
    numVM=$3
    vmSize=$4
    osDiskSize=$5
    dataDiskSize=$6
    publicIPName=$7

    echo -e \\n creating $(echo $vmName) VMs in $(echo $subnetName) subnet...
    if [ ! "$dataDiskSize" ]
    then
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $(echo $vmSize) \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nsg "" --public-ip-address "$publicIPName" \
                --vnet-name $vnetName --subnet $(echo $subnetName) \
                --os-disk-size-gb $(echo $osDiskSize) --storage-sku $storageType  --no-wait
        done
    else
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $(echo $vmSize) \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nsg "" --public-ip-address "$publicIPName" \
                --vnet-name $vnetName --subnet $(echo $subnetName) \
                --os-disk-size-gb $(echo $osDiskSize) --storage-sku $storageType --data-disk-sizes-gb $dataDiskSize  --no-wait
        done
    fi
}

# clone VM
clonevm () {
    vmName=$1
    newVmName=$2
    subnetName=$3
    numVM=$4
    vmSize=$5
    osDiskSize=$6
    dataDiskSize=$7
    publicIPName=$8

    diskId=$(az vm show -n $vmName -g $rgName -o tsv --query storageProfile.osDisk.managedDisk.id)
    diskSize=$(az vm show -n $vmName -g $rgName -o tsv --query storageProfile.osDisk.diskSizeGb)
    osType=$(az vm show -n $vmName -g $rgName -o tsv --query storageProfile.osDisk.osType)

    echo -e \\n creating $(echo $vmName) clone VM in $(echo $subnetName) subnet...
    if [ ! "$dataDiskSize" ]
    then
        for i in `seq $numVM`; do
            if [ "$publicIPName" ]
            then
                publicIP=$(echo $publicIPName)_$i
            else
                publicIP=""
            fi

            echo -e \\n creating copy of the OS disk...
            az disk create -g $rgName -n $(echo $newVmName)-$(echo $i)_osDisk --sku $storageType --source $diskId

            echo -e \\n creating $(echo $newVmName)-$(echo $i)...
            az vm create -n $(echo $newVmName)-$(echo $i) -g $rgName --size $(echo $vmSize) --attach-os-disk $(echo $newVmName)-$(echo $i)_osDisk \
                --nsg "" --public-ip-address "$publicIP" \
                --vnet-name $vnetName --subnet $(echo $subnetName) \
                --os-type $osType --os-disk-size-gb $(echo $osDiskSize)

            echo -e \\n setting hostname and rebooting VM...
            az vm run-command invoke -g $rgName -n $(echo $newVmName)-$(echo $i) --command-id RunShellScript --scripts \
                '(sudo hostnamectl set-hostname $1 && sleep 30 && sudo reboot) &' --parameters $(echo $newVmName)-$(echo $i)
        done
    else
        for i in `seq $numVM`; do
            if [ "$publicIPName" ]
            then
                publicIP=$(echo $publicIPName)_$i
            else
                publicIP=""
            fi

            echo -e \\n creating copy of the OS disk...
            az disk create -g $rgName -n $(echo $newVmName)-$(echo $i)_osDisk --sku $storageType --source $diskId

            echo -e \\n creating $(echo $newVmName)-$(echo $i)...
            az vm create -n $(echo $newVmName)-$(echo $i) -g $rgName --size $(echo $vmSize) --attach-os-disk $(echo $newVmName)-$(echo $i)_osDisk \
                --nsg "" --public-ip-address "$publicIP" \
                --vnet-name $vnetName --subnet $(echo $subnetName) \
                --os-type $osType --os-disk-size-gb $(echo $osDiskSize) --data-disk-sizes-gb $dataDiskSize
                
            echo -e \\n setting hostname and rebooting VM...
            az vm run-command invoke -g $rgName -n $(echo $newVmName)-$(echo $i) --command-id RunShellScript --scripts \
                '(sudo hostnamectl set-hostname $1 && sleep 30 && sudo reboot) &' --parameters $(echo $newVmName)-$(echo $i)
        done
    fi
}

# Generalize/capture VM
createvmimage () {
    vmName=$1
    newVmName=$(echo $vmName)-clone
    subnetName=$2

    diskId=$(az vm show -n $vmName -g $rgName -o tsv --query storageProfile.osDisk.managedDisk.id)
    diskSize=$(az vm show -n $vmName -g $rgName -o tsv --query storageProfile.osDisk.diskSizeGb)
    osType=$(az vm show -n $vmName -g $rgName -o tsv --query storageProfile.osDisk.osType)

    echo -e \\n initiating cloning and generalization for $vmName...

    echo -e \\n creating copy of the OS disk...
    az disk create -g $rgName -n $(echo $newVmName)-osDisk --sku $storageType --source $diskId

    echo -e \\n creating $(echo $newVmName)...
    az vm create -n $(echo $newVmName) -g $rgName --size Standard_b2ms --attach-os-disk $(echo $newVmName)-osDisk \
        --nsg "" --public-ip-address "" \
        --vnet-name $vnetName --subnet $(echo $subnetName) \
        --os-type $osType --os-disk-size-gb $(echo $diskSize)

    echo -e \\n deprovisioning VM...
    az vm run-command invoke -g $rgName -n $(echo $newVmName) --command-id RunShellScript --scripts \
        '(sudo sleep 60 && sudo waagent -deprovision -force && sudo shutdown -h now) &'
    
    echo -e \\n waiting for the VM to shutdown...
    az vm wait -g $rgName -n $newVmName --custom instanceView.statuses[?code=="'PowerState/stopped'"]
    az vm deallocate -g $rgName -n $newVmName

    echo -e \\n generalizing VM...
    az vm generalize -g $rgName -n $newVmName

    echo -e \\n creating image VM...
    newDiskId=$(az vm show -n $newVmName -g $rgName -o tsv --query storageProfile.osDisk.managedDisk.id)
    az image create -g $rgName -n $(echo $vmName)-image --source $newDiskId --os-type $osType

    echo -e \\n deleting clone VM...
    az vm delete -g $rgName -n $newVmName --yes --no-wait
}

createvmss () {
    lbType=$1
    lbName=$2
    subnetName=$3
    numVM=$4
    vmSize=$5
    osDiskSize=$6
    dataDiskSize=$7
    publicIPName=$8
    appgwsbcidr=$9

    vmName=$(echo $lbName)vm

    if [ "$1" = "app-gateway" ]
    then
        az network vnet subnet create -g $rgName --vnet-name $vnetName -n appGwSubnet --address-prefixes $appgwsbcidr
        lbParams="--app-gateway $lbName --app-gateway-capacity 2 --app-gateway-sku Standard_Medium --app-gateway-subnet-address-prefix $appgwsbcidr"
    else
        lbParams="--load-balancer $lbName --lb-sku Standard "
    fi


    echo -e \\n creating vm scale set in $(echo $subnetName) subnet...
    if [ ! "$dataDiskSize" ]
    then
        az vmss create -n $(echo $vmName) -g $rgName --image $image --vm-sku $(echo $vmSize) --instance-count $numVM \
            --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
            --nsg $(echo $subnetName)-nsg --public-ip-address "$publicIPName" \
            $lbParams \
            --vnet-name $vnetName --subnet $(echo $subnetName) \
            --storage-sku $storageType  --no-wait
    else
        az vmss create -n $(echo $vmName) -g $rgName --image $image --vm-sku $(echo $vmSize) --instance-count $numVM \
            --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
            --nsg $(echo $subnetName)-nsg --public-ip-address "$publicIPName" \
            $lbParams \
            --vnet-name $vnetName --subnet $(echo $subnetName) \
            --storage-sku $storageType --data-disk-sizes-gb $dataDiskSize  --no-wait
    fi
}

# create vm with internal load balancer in the front
createintlb () {
    lbName=$1
    subnetName=$2
    vmName=$3
    numVM=$4
    vmSize=$5
    osDiskSize=$6
    dataDiskSize=$7

    echo -e \\n creating $(echo $vmName) VMs with internal load balancer ...
    az network lb create --resource-group $rgName --name $(echo $lbName)LB --sku basic \
        --frontend-ip-name $(echo $lbName)FE --backend-pool-name $(echo $lbName)BE \
        --vnet-name $vnetName --subnet $(echo $subnetName) 

    echo -e \\n creating the NICs attached to this load balancer...
    for i in `seq $numVM`; do
    echo -e \\n creating $(echo $vmName)_nic$i...
    az network nic create --resource-group $rgName --name $(echo $vmName)_nic$i \
        --vnet-name $vnetName --subnet $(echo $subnetName) \
        --lb-name $(echo $lbName)LB --lb-address-pools $(echo $lbName)BE
    done

    echo -e \\n creating availability set...
    az vm availability-set create -n $(echo $vmName)av -g $rgName

    echo -e \\n creating $(echo $vmName) VMs in App subnet...
    if [ ! "$dataDiskSize" ]
    then
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $vmSize \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nic $(echo $vmName)_nic$i --availability-set $(echo $vmName)av  \
                --os-disk-size-gb $osDiskSize --storage-sku $storageType --no-wait
        done
    else
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $vmSize \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nic $(echo $vmName)_nic$i --availability-set $(echo $vmName)av  \
                --os-disk-size-gb $osDiskSize --storage-sku $storageType --data-disk-sizes-gb $dataDiskSize --no-wait
        done
    fi
}

# create vm with external L4 load balancer in the front with public IP
createextlb () {
    lbName=$1
    subnetName=$2
    vmName=$3
    numVM=$4
    vmSize=$5
    osDiskSize=$6
    dataDiskSize=$7

    echo -e \\n creating public IP for $(echo $vmName) VMs with public load balancer...
    echo -e \\n creating public IP for $(echo $lbName) load balancer...
    az network public-ip create --resource-group $rgName --name $(echo $lbName)pubIP \
        --sku standard --allocation-method static

    echo -e \\n creating public facing load balancer for $(echo $lbName) VMs...
    az network lb create --resource-group $rgName --name $(echo $lbName)LB --sku standard \
        --public-ip-address $(echo $lbName)pubIP --frontend-ip-name $(echo $lbName)FE \
        --backend-pool-name $(echo $lbName)BE

    echo -e \\n creating health probe for port 80...
    az network lb probe create --resource-group $rgName --lb-name $(echo $lbName)LB \
        --name healthprobe80 --protocol tcp --port 80

    echo -e \\n creating load balancing rule for HTTP...
    az network lb rule create --resource-group $rgName \
        --lb-name $(echo $lbName)LB --name HTTPRule --protocol tcp --frontend-port 80 --backend-port 80 \
        --frontend-ip-name $(echo $lbName)FE \
        --backend-pool-name $(echo $lbName)BE \
        --probe-name healthprobe80

    echo -e \\n creating health probe for port 443...
    az network lb probe create --resource-group $rgName --lb-name $(echo $lbName)LB \
        --name healthprobe443 --protocol tcp --port 443

    echo -e \\n creating load balancing rule for HTTPS...
    az network lb rule create --resource-group $rgName \
        --lb-name $(echo $lbName)LB --name HTTPSRule --protocol tcp --frontend-port 443 --backend-port 443 \
        --frontend-ip-name $(echo $lbName)FE \
        --backend-pool-name $(echo $lbName)BE \
        --probe-name healthprobe443

    echo -e \\n creating the NICs attached to this load balancer...
    for i in `seq $numVM`; do
    echo -e \\n creating $(echo $vmName)_nic$i...
    az network nic create --resource-group $rgName --name $(echo $vmName)_nic$i \
        --vnet-name $vnetName --subnet $(echo $subnetName) \
        --lb-name $(echo $lbName)LB --lb-address-pools $(echo $lbName)BE
    done

    echo -e \\n creating availability set...
    az vm availability-set create -n $(echo $vmName)av -g $rgName

    echo -e \\n creating $(echo $vmName) VMs in $(echo $subnetName) subnet...
    if [ ! "$dataDiskSize" ]
    then
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $(echo $vmSize) \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nics $(echo $vmName)_nic$i --availability-set $(echo $vmName)av  \
                --os-disk-size-gb $osDiskSize --storage-sku $storageType --no-wait
        done
    else
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $(echo $vmSize) \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nics $(echo $vmName)_nic$i --availability-set $(echo $vmName)av  \
                --os-disk-size-gb $osDiskSize --storage-sku $storageType --data-disk-sizes-gb $dataDiskSize --no-wait
        done
    fi
}

# create vm with external L7 load balancer in the front with public IP
createappgw () {
    appgwName=$1
    subnetName=$2
    vmName=$3
    numVM=$4
    vmSize=$5
    osDiskSize=$6
    dataDiskSize=$7

    echo -e \\n creating public IP for $(echo $vmName) VMs with App Gateway...
    echo -e \\n creating public IP for $(echo $lbName) app gateway...
    az network public-ip create --resource-group $rgName --name $(echo $appgwName)pubIP --sku standard --allocation-method static

    echo -e \\n creating subnet for app gateway...
    az network vnet subnet create --name appgw-subnet --resource-group $rgName --vnet-name $vnetName --address-prefix 10.0.5.0/24

    echo -e \\n creating the NICs for backend VMs...
    for i in `seq $numVM`; do
    echo -e \\n creating $(echo $vmName)_nic$i...
    az network nic create --resource-group $rgName --name $(echo $vmName)_nic$i --vnet-name $vnetName --subnet $(echo $subnetName)
    done

    echo -e \\n creating availability set...
    az vm availability-set create -n $(echo $vmName)av -g $rgName

    echo -e \\n creating $(echo $vmName) VMs in $(echo $subnetName) subnet...
    if [ ! "$dataDiskSize" ]
    then
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $(echo $vmSize) \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nics $(echo $vmName)_nic$i --availability-set $(echo $vmName)av  \
                --os-disk-size-gb $osDiskSize --storage-sku $storageType --no-wait
        done
    else
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $(echo $vmSize) \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nics $(echo $vmName)_nic$i --availability-set $(echo $vmName)av  \
                --os-disk-size-gb $osDiskSize --storage-sku $storageType --data-disk-sizes-gb $dataDiskSize --no-wait
        done
    fi

    echo -e \\n creating $(echo $appgwName)...
    for i in `seq $numVM`; do
    address=$(echo $address)" "$(echo $a)
        addresses=$(echo $addresses)" "$(az network nic show --name $(echo $vmName)_nic$i --resource-group $rgName | grep "\"privateIpAddress\":" | grep -oE '[^ ]+$' | tr -d '",')
    done

    az network application-gateway create --name $appgwName --location $location --resource-group $rgName \
    --capacity 1 --sku Standard_v2 --http-settings-cookie-based-affinity Enabled \
    --public-ip-address $(echo $appgwName)pubIP --http-settings-protocol Https --http-settings-port 443 \
    --vnet-name $vnetName --subnet appgw-subnet --servers $addresses --no-wait
}

createintappgw () {
    appgwName=$1
    subnetName=$2
    vmName=$3
    numVM=$4
    vmSize=$5
    osDiskSize=$6
    dataDiskSize=$7
    ports="$8"

    echo -e \\n creating subnet for app gateway...
    az network vnet subnet show -g $rgName -n intappgw-subnet --vnet-name $vnetName --query name >/dev/null 2>/dev/null \
      || az network vnet subnet create --name intappgw-subnet --resource-group $rgName --vnet-name $vnetName --address-prefix 10.0.7.0/24

    echo -e \\n creating the NICs for backend VMs...
    for i in `seq $numVM`; do
        echo -e \\n creating $(echo $vmName)_nic$i...
        az network nic create --resource-group $rgName --name $(echo $vmName)_nic$i --vnet-name $vnetName --subnet $(echo $subnetName)
    done

    echo -e \\n creating availability set...
    az vm availability-set create -n $(echo $vmName)av -g $rgName

    echo -e \\n creating $(echo $vmName) VMs in $(echo $subnetName) subnet...
    if [ ! "$dataDiskSize" ]
    then
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $(echo $vmSize) \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nics $(echo $vmName)_nic$i --availability-set $(echo $vmName)av \
                --os-disk-size-gb $osDiskSize --storage-sku $storageType --no-wait
        done
    else
        for i in `seq $numVM`; do
            az vm create -n $(echo $vmName)_$i -g $rgName --image $image --size $(echo $vmSize) \
                --authentication-type all --generate-ssh-keys --admin-username $adminUser --admin-password $adminPassword \
                --nics $(echo $vmName)_nic$i --availability-set $(echo $vmName)av \
                --os-disk-size-gb $osDiskSize --storage-sku $storageType --data-disk-sizes-gb $dataDiskSize --no-wait
        done
    fi

    echo -e \\n creating $(echo $appgwName)...
    unset addresses
    for i in `seq $numVM`; do
        addresses=$(echo $addresses)" "$(az network nic show --name $(echo $vmName)_nic$i --resource-group $rgName | grep "\"privateIpAddress\":" | grep -oE '[^ ]+$' | tr -d '",')
    done

    echo -e \\n initiating app gateway provisioning... 
    az network application-gateway show -g $rgName -n $appgwName --query name >/dev/null 2>/dev/null \
      || az network application-gateway create --name $appgwName --location $location --resource-group $rgName \
    --capacity 2 --sku Standard_Medium \
    --http-settings-protocol Http --http-settings-port 8080 --frontend-port 8080 \
    --vnet-name $vnetName --subnet intappgw-subnet

    echo -e \\n creating backend pool... 
    az network application-gateway address-pool create -g $rgName --gateway-name $appgwName -n $(echo $vmName)-pool --servers $addresses

    for i in $ports; do
        echo -e \\n creating frontend port $i... 
        az network application-gateway frontend-port create -g $rgName --gateway-name $appgwName -n $(echo $vmName)fe_$(echo $i) --port $i
        echo -e \\n creating http listener... 
        az network application-gateway http-listener create -g $rgName --gateway-name $appgwName --frontend-port $(echo $vmName)fe_$(echo $i) -n $(echo $vmName)listener_$(echo $i)
        echo -e \\n creating http setting... 
        az network application-gateway http-settings create -g $rgName --gateway-name $appgwName -n $(echo $vmName)setting_$(echo $i) --port $i --protocol Http --timeout 360
        echo -e \\n creating rule... 
        az network application-gateway rule create -g $rgName --gateway-name $appgwName -n rule_$(echo $i) --http-listener $(echo $vmName)listener_$(echo $i) --rule-type Basic \
        --address-pool $(echo $vmName)-pool --http-settings $(echo $vmName)setting_$(echo $i)
    done
}

addappgwrule () {
    appgwName=$1
    vmName=$2
    shift
    shift
    ports=$@

    for i in $ports; do
        echo -e \\n creating frontend port $i... 
        az network application-gateway frontend-port create -g $rgName --gateway-name $appgwName -n $(echo $vmName)fe_$(echo $i) --port $i
        echo -e \\n creating http listener... 
        az network application-gateway http-listener create -g $rgName --gateway-name $appgwName --frontend-port $(echo $vmName)fe_$(echo $i) -n $(echo $vmName)listener_$(echo $i)
        echo -e \\n creating http setting... 
        az network application-gateway http-settings create -g $rgName --gateway-name $appgwName -n $(echo $vmName)setting_$(echo $i) --port $i --protocol Http --timeout 360
        echo -e \\n creating rule... 
        az network application-gateway rule create -g $rgName --gateway-name $appgwName -n rule_$(echo $i) --http-listener $(echo $vmName)listener_$(echo $i) --rule-type Basic \
        --address-pool $(echo $vmName)-pool --http-settings $(echo $vmName)setting_$(echo $i)
    done

}

addlbrule () {
    lbName=$1
    shift
    ports=$@

    for i in $ports; do
        echo -e \\n creating health probe for port $i...
        az network lb probe create --resource-group $rgName --lb-name $(echo $lbName)LB \
            --name healthprobe$(echo $i) --protocol tcp --port $i

        echo -e \\n creating load balancing rule for port $i...
        az network lb rule create --resource-group $rgName \
            --lb-name $(echo $lbName)LB --name rule$(echo $i) --protocol tcp --frontend-port $i --backend-port $i \
            --frontend-ip-name $(echo $lbName)FE \
            --backend-pool-name $(echo $lbName)BE \
            --probe-name healthprobe$(echo $i)
    done
}

deletelbrule () {
    lbName=$1
    shift
    ports=$@

    for i in $ports; do
        echo -e \\n deleting load balancing rule for port $i...
        az network lb rule delete --resource-group $rgName \
            --lb-name $(echo $lbName)LB --name rule$(echo $i)

        echo -e \\n deleting health probe for port $i...
        az network lb probe delete --resource-group $rgName --lb-name $(echo $lbName)LB \
            --name healthprobe$(echo $i)
    done
}

addnsgrule () {
    nsgName=$1
    shift
    ports=$@
    count=$(az network nsg rule list --nsg-name $nsgName -g $rgName --query [].[access,priority] -o tsv |grep ^Allow |cut -f 2 |sort -g |tail -1)
    count=${count:-100}

    for i in $ports; do
        echo -e \\n adding nsg rule for port $i...
        count=$(expr $count + 1)
        az network nsg rule create -g $rgName --nsg-name $nsgName -n Allow$(echo $i) --priority $count \
        --protocol Tcp --access Allow --destination-port-ranges $i
    done
}

deletensgrule () {
    nsgName=$1
    shift
    ports=$@

    for i in $ports; do
        echo -e \\n deleting nsg rule for port $i...
        az network nsg rule create -g $rgName --nsg-name $nsgName -n Allow$(echo $i)
    done
}

createbaseinfra() {
    rgName=$1
    location=$2
    vnetName=$3
    addressPrefix=$4

    # creation starts from here
    echo -e \\n creating resource group...
    az group create -n $rgName -l $location

    echo -e \\n creating Virtual Network...
    az network vnet create -g $rgName -n $vnetName --address-prefix $addressPrefix
}

createsubnet() {
    subnetName=$1
    vnetName=$2
    addressPrefix=$3
    ports=$4

    echo -e \\n creating network security groups for the subnet...
    nsgName=$(echo $subnetName)-nsg
    az network nsg create -g $rgName -n $nsgName

    if [ ! "$ports" ]
    then
        echo -e \\n creating allow all incoming rule for NSG.. 
        count=$(az network nsg rule list --nsg-name $nsgName -g $rgName --query [].priority -o tsv |sort -g |tail -1)
        count=${count:-100}
        az network nsg rule create -g $rgName --nsg-name $nsgName -n AllowAll --priority $count \
            --protocol Tcp --access Allow --protocol Tcp --destination-port-ranges '*'
    else
        count=$(az network nsg rule list --nsg-name $nsgName -g $rgName --query [].priority -o tsv |sort -g |tail -1)
        count=${count:-100}
        for i in $ports; do
            echo -e \\n adding nsg rule for port $i...
            count=$(expr $count + 1)
            az network nsg rule create -g $rgName --nsg-name $nsgName -n Allow_$(echo $i) --priority $count \
                --protocol Tcp --access Allow --protocol Tcp --destination-port-ranges $i
        done
    fi

    echo -e \\n creating subnet...
    az network vnet subnet create -g $rgName --vnet-name $vnetName -n $subnetName --address-prefixes $3 \
        --network-security-group $(echo $subnetName)-nsg

}

createasg () {
    asgName=$1
    shift
    vmNames=$@

    echo -e \\n creating the application security group $asgName...
    az network asg show -n $asgName -g $rgName >/dev/null 2>/dev/null \
      || az network asg create -n $asgName -g $rgName

    for i in $vmNames; do
        nicId=$(az vm nic list --vm-name $i -g $rgName -o tsv --query [0].id)
        nicName=$(az vm nic list --vm-name $i -g $rgName -o tsv --query [0].id |awk -F/ '{print $NF}')
        ipConfigName=$(az network nic show -n $nicName -g $rgName -o tsv --query ipConfigurations[0].name)

        echo -e \\n adding $i to $asgName...
        az network nic ip-config update --application-security-groups $asgName -n $ipConfigName --nic-name $nicName -g $rgName
    done
}

addasgrule () {
    nsgName=$1
    sourceasgName=$2
    destasgName=$3
    shift
    shift
    shift
    ports=$@
    count=$(az network nsg rule list --nsg-name $nsgName -g $rgName --query [].[access,priority] -o tsv |grep ^Allow |cut -f 2 |sort -g |tail -1)
    count=${count:-100}

    count=$(expr $count + 1)
    az network nsg rule create -g $rgName --nsg-name $nsgName -n Allow-$(echo $ports |tr " " "-") \
        --priority $count --source-asgs $sourceasgName --destination-port-ranges $ports \
        --destination-asgs $destasgName --access Allow --protocol Tcp \
        --description "Allow $sourceasgName to $destasgName on ports $ports"
}

deleteasgrule () {
    nsgName=$1
    shift
    ports=$@

    az network nsg rule delete -g $rgName --nsg-name $nsgName -n Allow-$(echo $ports |tr " " "-")
}

