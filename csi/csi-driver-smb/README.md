# [`kubernetes-csi/csi-driver-smb`](https://github.com/kubernetes-csi/csi-driver-smb "GitHub")


>This driver allows Kubernetes to access SMB Server on both Linux and Windows nodes.


The filesystem format (NTFS, FAT32, ...) is irrelevant.   
The CIFS (SMB) protocol handles that.

Note __LUNs__ are block-level logical storage volumes presented to servers 
from a Storage Area Network (__SAN__). 


### NetApp ONTAP protocols:

- `nfs`
- `cifs` (SMB)
- `iscsi`
- `fcp`
- `nvme`

NetApp ONTAP __administrators__ may *reference* the LUN of a SAN   
that is shared by CIFS protocol as "__`san-cifs`__" .

## [`csi-driver-smb.sh`](csi-driver-smb.sh)


### [Examples](https://github.com/kubernetes-csi/csi-driver-smb/tree/master/deploy/example "GitHub")

- `StorageClass` : [example-storageclass-smb.yaml](example-storageclass-smb.yaml)
- `PersistentVolume` : [`example-pv-smb.yaml`](example-pv-smb.yaml)