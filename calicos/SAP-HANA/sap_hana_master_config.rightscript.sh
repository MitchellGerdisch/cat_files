#! /usr/bin/sudo /bin/bash

# Port of the user-data script for the SAP-Hana master node from the quick start CFT
#
# INPUTS
#   PRIVATEBUCKET - default: "quickstart-reference/sap/hana/latest"
#   STACKNAME - passed by CAT: deployment ID
#	CFT implies this is a proper name but I'm just gonna keep it simple
#   STACKID - passed by CAT: deployment ID
#   SAPAMICODE - default: SLES12SP1SAPHVM
#	Comes from a mapping in the CFT. Since I'm just doing this one AMI for now, I'll just use a default input.
#   HOSTCOUNT - passed by CAT based on the number of nodes to be deployed in the cluster.
#   SAPINSTANCENUM - passed by CAT. Represents the number assigned to this node.	
#   DOMAINNAME - default: local
#   HANAMASTERHOSTNAME - default: imdbmaster
#   HANAMASTERWORKERNAME - default: imdbworker
#   HOSTCOUNT - default: 1

mkdir /root/install
wget "https://s3.amazonaws.com/$PRIVATEBUCKET/scripts/download.sh --output-document=/root/install/download.sh

sh /root/install/download.sh -b $PRIVATEBUCKET
chmod 755 /root/install/*.sh
chmod 755 /root/install/*.py


echo "export TABLE_NAME=HANAMonitor_$STACKNAME" >> /root/install/config.sh
# SKIPPING FOR NOW: echo "export DeploymentInterruptQ=$DEPLOYMENTINTERRUPTQ >> /root/install/config.sh
echo "export MyOS=$SAPAMICODE" >> /root/install/config.sh
                                
sh /root/install/writeconfig.sh MyStackId=$STACKID
# Fixing to "yes" for now
sh /root/install/writeconfig.sh INSTALL_HANA=Yes
sh /root/install/writeconfig.sh HostCount=$HOSTCOUNT
sh /root/install/writeconfig.sh SAPInstanceNum=$SAPINSTANCENUM
sh /root/install/writeconfig.sh IsMasterNode=1
sh /root/install/writeconfig.sh IsWorkerNode=0
# These volume settings were hard-coded in the CFT, so just doing the same here.
sh /root/install/writeconfig.sh BACKUP_VOL=st1
sh /root/install/writeconfig.sh SHARED_VOL=gp2
sh /root/install/writeconfig.sh USR_SAP_VOL=gp2
# SKIPPING export WaitForMasterInstallWaitHandle=", "Ref": "WaitForMasterInstallWaitHandle" >> /root/install/config.sh\n",
echo export REGION="us-east-1" >> /root/install/config.sh
sh /root/install/install-aws.sh
sh /root/install/install-prereq.sh
# #sh /root/install/signal-complete.sh
sh /root/install/cluster-watch-engine.sh -c
sh /root/install/cluster-watch-engine.sh -i "DomainName=$DOMAINNAME"
sh /root/install/cluster-watch-engine.sh -i MyHostname=$HANAMASTERHOSTNAME",
sh /root/install/cluster-watch-engine.sh -i "MyRole=Master"
sh /root/install/cluster-watch-engine.sh -i "HostCount=$HOSTCOUNT"
sh /root/install/cluster-watch-engine.sh -i "Status=PRE_INSTALL_COMPLETE"
sh /root/install/reconcile-ips.sh $HOSTCOUNT >> /root/install.log\n",
sh /root/install/fence-cluster.sh -w "PRE_INSTALL_COMPLETE_ACK=$HOSTCOUNT"
sh /root/install/install-master.sh -s ",
#                                {
#                                    "Ref": "SID"
#                                },
#                                " -i ",
#                                {
#                                    "Ref": "SAPInstanceNum"
#                                },
#                                " -p ",
#                                {
#                                    "Ref": "HANAMasterPass"
#                                },
#                                " -n ",
#                                {
#                                    "Ref": "HANAMasterHostname"
#                                },
#                                " -d ",
#                                {
#                                    "Ref": "DomainName"
#                                },
#                                " -w ",
#                                {
#                                    "Ref": "HANAWorkerHostname"
#                                },
#                                "\n",
#                                "sh /root/install/cluster-watch-engine.sh -s \"MASTER_NODE_COMPLETE\"\n",
#                                "sh /root/install/wait-for-workers.sh ",
#                                {
#                                    "Ref": "HostCount"
#                                },
#                                "\n",
#                                "sh /root/install/cluster-watch-engine.sh  -r \n",
#                                "sh /root/install/validate-install.sh \"",
#                                {
#                                    "Ref": "WaitForMasterInstallWaitHandle"
#                                },
#                                "\" \n",
#                                "#python /root/install/postprocess.py \n",
#                                "sh /root/install/cleanup.sh \n",
#                                "\n",
#                                "\n"
#                            ]
#                        ]
