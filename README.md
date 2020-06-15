# oci-quobyte
Deploy [Quobyte file system](https://www.quobyte.com) on Oracle Cloud Infrastructure. The template will do the following: 

- Provision the infrastructure resources required to deploy the filesystem. This includes VCN, public, private, internet, nat gateways, security list,  compute instances and storage.   
- Deploys Quobyte filesystem.  Please plan to signup for a 45 day free license for  Quobyte [here](https://www.quobyte.com/signup).  
- Deploys client/compute node to mount the filesystem.
- You can deploy Quobyte on Bare metal or Virtual Machine compute nodes.  These node can be Standard, DenseIO (local SSD) or HPC compute shapes
- Minimum 4 fileserver nodes are required.
- Storage Tiering - You can use more than one storage type: local NVMe SSD (physically attached to the host machine) and different OCI Block Storage elastic performance tiers (Higher/Balanced/Lower Cost) to meet your storage performance and cost needs.   
- Using Bare metal nodes is recommended, so you can use 2x25Gbps NICs for optimal performance.



## Quobyte
#### Why Quobyte
- Parallel distributed POSIX file system
- Unlimited performance through scale out without bottlenecks
- Reliability through erasure coding and replication on local NVMe or through Block Volumes
- Easy to use and run, on VMs and bare metal servers
- Unified storage with native drivers for Linux, Windows, S3, HDFS, MPI-IO and TensorFlow
- Automatic tiering between storage media and clusters

#### Key Features
- Single namespace for File, S3, Hadoop, MPI, TensorFlow
- Multi-Tenancy with optional hardware isolation
- Policy-based data placement
- Fairness between IO streams, workloads and users on metadata
- Workload and user isolation
- Scalable range locks
- File striping
- Recoding for space efficiency
- Data mover between clusters
- Quotas without performance impact
- NFSv4 ACLs across all platforms
- IP-based and X.509-based access control
- Untrusted clients (X.509 certificate support)
- Unlimited number of volumes with thin provisioning

#### Differentiator from other Parallel FS/NAS solutions
- Shared-nothing, built-in data protection with synchronous, asynchronous replication and erasure coding
- User-space drivers for easy installation and updates without kernel modules
- Enterprise features such as automatic policy-based tiering, re-protection, expiration
- Reconfiguration and updates at any time without interruption
- MPI-IO support with kernel bypass

#### Workloads – it works well for
- Throughput workloads, e.g. machine learning, traditional HPC
- Small file workloads, e.g. fluid dynamics, EDA
- Random 4k IO
