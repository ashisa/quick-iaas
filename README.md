# Quick-IaaS for Azure

Quick-IaaS for Azure is a Azure CLI 2.x powered script toolkit that allows you to quickly spin up your IaaS architecture on Azure. It covers most of your requirements and if you come across any scenarios that you need, please feel freet create an issue or better - submit a PR.

## Why?

Azure CLI 2.0 is a awesome and just like the flexibility that you get with Azure, it allows you to do just about anything that you can from the portal or any other way. And, as such it requires that much more input to get going.

Quick-IaaS builds on top of Azure CLI 2.x and allows you to chain the Azure CLI commands with just a few parameters on the command line and orchestrate the most common IaaS deployments on Azure.

Well, it also does some stuff that are common but are complex or not possible out of the box such as cloning or generalizing a VM without making is unuseable. You can also create VM image and use them to quick build VMs or VM Scale Set to expedite time to production.

## How to use it?

Make a clone of this repo and source the functions.sh in your scripts or DevOps pipelines.

```
git clone https://github.com/ashisa/quick-iaas.git
source functions.sh
```
If you do this from the command line, you will see the information on what environment variables you need to set and what functions are made available in your shell that you can use to start deploying your IaaS architecture -

```
Setting up the following variables for successful execution of shell functions...
        rgName
        location
        vnetName
        subnetDMZ
        subnetApps
        subnetCommmon
        adminUser
        adminPassword
        storageType
        image
        fileshareName

Please change values of these variables as necessary.

Functions:
Create the resource group and vnet -
createbaseinfra resource-group-name location vnet-name vnet-cidr-address-range

Create the resource group and vnet -
createsubnet name-of-subnet vnet-name subnet-cidr-address-range nsg-ports-to-open

Create standalone VMs - no lb/appgw -
createvm vm-name-prefix subnet-name number-of-vm vm-size os-disk-size data-disk-size public-ip-if-needed

Clone a VM of a running/deallocated VM -
clonevm vm-to-be-cloned clone-vm-name-prefix subnet-name number-of-vms vm-size os-disk-size data-disk-sizes public-ip-if-needed

Create an image of a VM without capturing the original VM -
createvmimage vm-name-to-be-imaged subnet-name

Create a VM Scale Set -
createvmss type-of-load-balancer lb-name subnet-name number-of-vms vm-size os-disk-size data-disk-sizes public-ip-if-needed cidr-for-appgw-if-used

Create VMs with internal load balancer (L4) -
createintlb lb-name-prefix subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed

Create VMs with external load balancer (L4) -
createextlb lb-name-prefix subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed

Create VMs with public application gateway (L7) -
createappgw appgw-name subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed

Create VMs with internal application gateway (L7) -
createintappgw appgw-name subnet-name vm-name-prefix number-of-vms vm-size os-disks-size data-disk-size ports-for-appgw-rules

Add Application Gateway rules for an existing gateway -
addappgwrule appgw-name vm-name-prefix ports-for-appgw-rules

Add Load Balancer (L4) rules -
addlbrule lb-name ports-space-separated

Delete Load Balancer (L4) rules -
deletelbrule lb-name ports-space-separated

Add Network Security Group (nsg) rules -
addnsgrule nsg-name ports-space-separated

Delete Network Security (nsg) rules -
deletensgrule nsg-name ports-space-separated
```
It also sets them up with predefined values so that your functions do not fail unexpectedly. You should set them with the appropriate values in your main script.

Once you have done that, you can now call the following functions to start deploying your IaaS setup.

### Creating resource group and virtual network -
```
createbaseinfra $rgName $location $vnetName 10.0.0.0/16
```
This function creates a resource group and a virtual network with the CIDR address range defined. You can call these functions with the values right on the commands line or you can use the environment variables defined earlier.

This is needed to be done only once as is the next step which is to create subnets using the ***createsubnet*** function -
```
createsubnet $subnetApps $vnetName 10.0.1.0/24 "22 80 443 3000-3005"
```
This creates a subnet in the given virtual network with the CIDR address range specified. If also create an associated Network Security Group (subnet-nsg) and creates the NSG rules to open the ports and/or port-ranges provided as arguments. If you skip the last parameters, if creates a rule to allow all imcoming traffic.

When dealing with existing Network Security Groups, you can use the ***addnsgrule/deletensgrule*** functions to add/remove rules -
```
addnsgrule apps-subnet-nsg 22 80 443 300-3005

deletensgrule apps-subnet-nsg 22
```
The first commands adds the rules for the ports specified and the next command deletes the rule created earlier for the port 22.

Now that we are ready with our resource group, virtual network, subnets and network security groups, we can move on to creating the VMs in various configurations -

### Create VMs -
***createvm vm-name-prefix subnet-name number-of-vm vm-size os-disk-size data-disk-size public-ip-if-needed***

Example:
```
createvm jumpbox $subnetDMZ 1 Standard_B2MS 32 "" jumpboxPIP
```
This command creates a jumpbox VM with a public IP in the DMZ subnet.

```
createvm websrv $subnetApps 2 Standard_D4s 32 "64 64"
```

Note: You can find the VM sizes using the following command -
    ```
    az vm list-sizes -o table -l southindia
    ```

This command creates two web server VMs - *websrv_1* and *websrv_2* - in the Apps subnet with a 32GB OS disk and two 64GB data disks. As the last parameter for the public IP is missing, these VMs will not be accesible over the Internet so you need to use the jumpbox the access them.

While on the topic, you can do much with the VMs using Quick-IaaS - first, create a clone of a VM to scale out your servers and second, you can create an image of a VM so that you can use the to create VMs or VM scale sets - this one without touching the master VM since we make a clone and generalize that for use.

### Cloning a VM -

***clonevm vm-to-be-cloned clone-vm-name-prefix subnet-name number-of-vms vm-size os-disk-size data-disk-sizes public-ip-if-needed***

```
clonevm websrv_1 prod-web-srv $subnetApps 2 Standard_B2MS 32 "64 64"
```

What this one does under the hood is that is makes copies of the OS disk attached to *websrv_1* VM and brings up two VMs honorign the rest of the parameters - two VMs in the App subnet with 32GB of the OS disk and two 64GB data disks and no public IPs. Since we can making copy of the OS disk, the function also goes ahead and changes the hostnames so that your DNS resolutions work fine.

Note:
1. It make clone of running VMs but you are advised to stop the VM so that the copies are file-consistent.
2. Please use "-" instead of "_" when cloning VMs.

### Creating VM image -
A better approach to take is to generalize a VM and using the same methodology, you can generalize and create an image of VM by first cloning and then generalizing that -

***createvmimage vm-name-to-be-imaged subnet-name***
```
createvmimage websrv_1 $subnetApps
```
This function makes a clone of websrv_1 (so please shut it down a sec), deprovisions, shuts down, generalizes it and then finally creates an image of it for further use in the same resource group.

It also deletes the clone VM so that you don't have any lingering artifacts.

To use this image with the *createvm* function, you just need to set the *image* variable to the name of the image created -

```
image=websrv_1-image
createvm prod-web-srv $subnetApps 2 Standard_D4s 32
```
This will create two VMs using the image that was created in the previous step. 

### Create VM Scale Sets -
Next step is to create VM Scale Set and you do that with *createvmss* function -

***createvmss type-of-load-balancer lb-name subnet-name number-of-vms vm-size os-disk-size data-disk-sizes public-ip-if-needed cidr-for-appgw-if-used***

```
createvmss load-balancer websrv $subnetApps 4 Standard_B2MS 32 "" prod-web-srv-PIP
```
This command creates a VM scale with 4 VM instances and an Intenet facing Azure Load Balancer for load balancing. This also works with your images that you may have created with the *createvmimage* function. 

To use any marketplace image, just set the image variable with appropriate value -
```
image=UbuntuLTS
```
Eliminate the Public IP name parameter if you want to create an internal private VM Scale Set -
```
createvmss load-balancer websrv $subnetApps 4 Standard_B2MS 32
```
This command creates a VM Scale Set in the Apps subnet with 32GB in the Apps subnet and no Public IP addresses.

If you want to use an Application Gateway instead with VM Scale Sets, you need to use the following syntax -
```
createvmss app-gateway websrv $subnetApps 4 Standard_B2MS 32 "" prod-web-srv-PIP 10.0.6.0/24
```
A CIDR address range is needed as the last parameter as that's where the Application Gateway instance will be created.

*Note: There doesn't seem to be a way to create an internal VM scale set with Application Gateway so that's not an option at the moment. VM Scale Set with Application Gateway will be an Internet facing set up.*

Now for the other IaaS configurations on Azure with Quick-IaaS.

### Creating VMs with Load Balancers -

Creating an internal load balancer with a bunch of VMs in the backend pool -

***createintlb lb-name-prefix subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed***
```
createintlb apisrv $subnetApps websrv 2 Standard_B2MS 32
```
This command creates an internal load balancer in the Apps subnet with 2 VM added to the backend pool. If you want add data disks just add them in double quotes at the end.

Creating an external load balancer is done with the createextlb function -

***createextlb lb-name-prefix subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed***
```
createextlb websrv $subnetApps websrv 4 standard_b2ms 32 128
```
This will create an external load balancer with a public IP and 4 VMs in the backend pool. It also creates load balancing rules for ports 80 and 443.

If you want to add/delete load balancer rules, you can use the following functions -

***addlbrule lb-name ports-space-separated***

***deletelbrule lb-name ports-space-separated***

```
addlbrule websrvlb 4000 5000 6000

deletelbrule websrvlb 4000 5000 6000
```

### Creating VMs with Application Gateway in front of them -

Load Balancers on Azure are L4 load balancers, if you are looking for L7 load balancers, you need to use Application Gateways -

Creating VMs with internal L7 load balancer -

***createintappgw appgw-name subnet-name vm-name-prefix number-of-vms vm-size os-disks-size data-disk-size ports-for-appgw-rules***
```
createintappgw websrvappgw $subnetApps web-srv 2 standard_b2ms 32 "" "80 443"
```
This will create an internal L7 load balancing Application Gateway called websrvappgw with a backend pool which contains web-srv_1 and web-srv_2 and creates rules for ports 80 and 443.

If you need to add more backend pools to this Application Gateway all you need to call the same command and re-use the Application Gateway name -
```
createintappgw websrvappgw $subnetApps api-srv 2 standard_b2ms 32 "" "3000 4000"
```
This add a new backend pool for the same Gateway instance and create the rules for the ports defined as the last parameter.

Add more rules to an existing internal Application Gateway -

***addappgwrule appgw-name vm-name-prefix ports-for-appgw-rules***
```
addappgwrule websrvappgw api-srv "3003 3004"
```
This will work for an existing internal application gateway instance which was creating using *createintappgw* function. 

**Creating an Internet facing Application Gateway deployment** -

If you want to create an Internet facing Application Gateway set up, use the following command -

***createappgw appgw-name subnet-name vm-name-prefix number-of-vm vm-size os-disk-size data-disk-size-if-needed***
```
createappgw web-srv-appgw $subnetApps web-srv 2 standard_b2ms 32 64 
```

This create an Internet facing Application Gateway with 2 VMs in the backend pool and add HTTP load balancing rule.

That sums it all! Hope you find it useful. Suggestions/PRs welcome!!