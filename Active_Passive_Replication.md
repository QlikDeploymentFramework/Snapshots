# Active/Passive site replication with Qlik Sense Enterprise Shared Persistence
In this article we will describe how to setup a constant replication between primary (active) Qlik Sense site and a secondary (passive) backup site. This is a design option that is quite common in high availability scenarios. Below is a simple schematics of an Active/Passive site replication setup.
![N|Solid](https://raw.githubusercontent.com/QlikDeploymentFramework/Snapshots/master/Images/Active_passive.jpg)

## Snapshots Tool
The Snapshots Tool is a command line script that running on the central node creates backup snapshots of the current environment. The snapshots can then be copied to another site's central node and revert the snapshot. If identified the snapshots tool will change important settings to the once identified on the new site. Last as it's a command line script it's easy to modify to fit the current system needs. Making it easy to adapt, dependent on the use case and the environment at hand.

## Local server alias names
To create a workable replication the servers in each site need to have the same local alias names, so that the replicated database could find the rim nodes "on the other side". Local names are not the same as computer names that must be unique, local names are created by mapping IP in the hosts file of each server.Site A hosts file maps to his local names and correlating IP numbers while B have the exact set of names but mapping to site B's IP numbers. If a new node is added the hosts file need to be updated on all servers in A and B. 
##### Hosts file example
```sh
# Data center A
192.168.1.101   CN
192.168.1.102   P1
192.168.1.103   P2
  
# Data center B
192.168.2.101   CN
192.168.2.102   P1
192.168.2.103   P2
```
## Internal certificates
Qlik Sense use internal certificates to communicate securely across the nodes, the certificates also encrypts connection string passwords. This makes it important to reuse the same certificates across both sites, for this to work it's important to (during primary site install) register the root certificate as the Central Node local name, in our case CN. When this done certificates can be exported and imported into the passive site. The export is done automatically using the snapshots tool, the certificates will be stored in the snapshot after copy and import these into the central node on the passive site. Using snapshots tool Root and Personal certificates are backuped in the root folder while client certificate is located under `Exported Certificates\.Local Certificates` within each snap.
## File content replication
Qlik Sense Shared Persistence uses a common file share within each site. In active/passive scenario the share usually need to be replicated to the other datacenter. This replication can be done in several ways, using Windows DFS-R, internal replication tools or simple robocopy mirroring. The Snapshots tool will (independent on replication method) modify the QSR DB file share UNC path entries to fit each site.
## QSR DB replication
PostgreSQL have built in active/passive replication functionality that usually works well for Qlik Sense. But in the case we need to change file share location settings after replication (as we have an alternate file share URL in Data Center B) the Snapshot tool a becomes a better fit.
## Common DNS Alias
To switch between the active and passive datacenters a common dns alias `QlikSense.Company.com` is needed, this in combination with an external load-balancer that spreads the load across proxies within the active site. To change between the systems this dns need to be changed manually or automatic as several load-balancers have support for monitoring and failover between datacenters.
## Stop and start Qlik services during recovery
On the passive site it's critical that all Qlik services on all rim nodes are shut down during database recovery. As the `snapshots.cmd` script is run on the central node it will shutdown and startup appropriate services on central node (but only on this node).
# Step by step instructions
These instructions are for a setup using a file share and QSR database stored locally on the central node on each site. Replication is done between the sites using the `Snapshots.cmd` script (robocopy). Prerequisite is that infrastructure have previously been setup on each datacenter, this includes the load balancer and public DNS alias.
1. Create hosts files for both sites adding the local server names and the corresponding IP addresses in the (form of IP NAME), add the hosts file on each server `%windir%\System32\drivers\etc` in both sites.
2. Create a Windows share on data center A, could be on the primary central node disk area or on another file area. The Qlik Sense service account need full access to this share.
3. Run Qlik Sense setup on the central node on the site A, select creating a new Shared Persistent site. When asked for server name type the local server name instead of default. When asked for share URL point to the already created Windows share on data center A.
4. Run Qlik Sense setup on the rim nodes in site A, select joining a Shared Persistent site.
5. Start QMC on the central node (use `https://localhost/qmc`) using a domain account! The first user gets root access and we do not want a local account getting that access. Add licenses and optionally create a connection to the Active Directory UDC and sync some users.Here we can also setup admin access to aditional users or groups.
6. In QMC add both rim nodes using the local names of the rim nodes. Reboot all the rim node servers after initiation, check in the qmc node section that they comes back up.
7. In QMC setup proxy settings and add licence rules for your needs to make the primary site workable.
8. Optionally add the same public certificate (wildcard or public DNS name) to all rim nodes in both sites. Alternative an advanced load balancer like f5 can handle encryption, instead using http in behind.
9. If using SAML the setup need to be done using the common dns alias `QlikSense.Company.com`, this means changing the metadata after export from Qlik Sense
10. When the primary site is working as it should, run the `snapshots.cmd` (as Administrator) on the central node using the same account running the services (else you will not export all certificates)
11. Open the Snapshots snap folder created, there should be three cert files, in our case their names are `root.pfx`, `server.pfx`, `client.pfx`. Copy these files to the passive central node in data center B. In the snap also copy `ExportedCertificates\.Local Certificates` folder.
12. Repeat step 2 and 3 replacing data center A with B. Do NOT add rim nodes just yet, as we need to change the certificates first.
13. Copy the `.Local Certificates` folder (from the snapshot) to `%programdata%Qlik\Sense\Repository\Exported Certificates` (you can rename the original to Local Certificates_org) 
14. Stop all Qlik Services on the passive central node
15. On the passive central node (as the service account) open mmc and add the certificates snap-in twice, as My user account and Computer account (local computer)

  * First open certificates `Local Computer/Trusted Root Certification Authorities/Certificates` and find the Qlik Sense local cert in our case `CN-CA` (the same name as copied) delete this cert. After import the `root.pfx` cert file we copied from active central node. The default import password is `QlikSense`.
  * Now go into `Local Computer/Personal/Certificates` and replace the `personal certificate`, in our case CN is deleted and replaced (import) by the `server.pfx`, default import password is QlikSense.
  * Last go into `Current User/Personal/Certificates` and replace `QlikClient` with `client.pem` located under `Exported Certificates\.Local Certificates`
16. Start Qlik services on passive central node. Repeat steps 5-10 replacing data center A with B
17. Now when you have both sites running you should be able to replicate snaps between A and B, lets try it
  * Create a snapshot on active central node (A), copy the snap to passive central node (B) under the `snapshots.cmd` snaps folder
  * On passive central node (B) run snapshots.cmd (as Administrator) and select the snap from A, the snap name should be date + computername from A. Security backup from B will be created first and second the recovery from A will run, last settings (like file share url) will be applied on the database.
  * Validate that the Qlik Sense environment (central + rim nodes) is working on data center B
18. if everything works correct in data center B automation can be applied to automatically create and move snaps from A to B. There are some switches to apply to `Snapshots.cmd` that helps during automation.
  * Create a fixed Central Node snapshot on site A applying switch `snapshots.cmd silent snapshot_name`
  * Copy `snapshot_name` to Central Node on site B
  * Recover Central Node on site B using the switch snapshots.cmd restore snapshot_name
19. It's important to stop all Qlik Sense services on all passive nodes (except repository database on central node) before the recovery. An option is to in the `snapshots.cmd` command line script add the SC command that have support for remote stop and start of services.
